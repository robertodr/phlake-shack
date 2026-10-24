"""Protected one-shot maintenance state, not an authorization/provisioning API.

Mutators require the caller to hold publish.installer_lock for the whole operation.
No command here touches keys, the ESP, TPM, LUKS or boot selection. An interrupted
record stays in place; no replay, repair, deletion or inferred physical acceptance.
Owner means effective caller (production CLI independently requires root).
"""

from dataclasses import dataclass, field
import hashlib
import json
import os
from pathlib import Path
import re
import stat

from .filesystem_identity import filesystem_identity

MAX_BYTES = 65536
PHASES = {
    "issuer": ("prepared", "exchanged", "published", "manual-boot-accepted", "complete"),
    "parent": ("transient-verified", "persistent-verified", "complete"),
    "enrollment": ("token-written", "token-verified", "attended-boot-accepted", "complete"),
}
ACTIONS = {"install", "cleanup", "confirm-boot", "reconcile", "prune"}
CANDIDATE_FIELDS = {"entry_id", "closure", "sha256", "pcr_key_fingerprint"}
ENTRY = re.compile(r"dancer-([0-9a-f]{64})\.efi")
HASH = re.compile(r"[0-9a-f]{64}")
CLOSURE = re.compile(r"/nix/store/[0123456789abcdfghijklmnpqrsvwxyz]{32}-[A-Za-z0-9+._?=-]+")
ASSETS = {"artifacts", "staged-pair"}


def _directory(path):
    info = path.lstat()
    if (not stat.S_ISDIR(info.st_mode) or info.st_uid != os.geteuid()
            or stat.S_IMODE(info.st_mode) != 0o700
            or path.resolve(strict=True) != path.absolute()
            or path.is_relative_to(Path("/nix/store"))):
        raise ValueError("unsafe migration directory")
    return info


def _binding(path):
    expected = _directory(path)
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        info = os.fstat(fd)
        if (info.st_dev, info.st_ino, info.st_uid, info.st_mode) != (
                expected.st_dev, expected.st_ino, expected.st_uid, expected.st_mode):
            raise ValueError("migration directory replaced before identity read")
        return {"filesystem": filesystem_identity(fd), "inode": info.st_ino}
    finally:
        os.close(fd)


def _sync_directory(path):
    _directory(path)
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def _unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate migration JSON field")
        result[key] = value
    return result


def _nonfinite(_):
    raise ValueError("nonfinite migration JSON value")


def _bounded(value, depth=0):
    if depth > 16:
        raise ValueError("migration JSON nesting exceeds bound")
    if isinstance(value, dict):
        if len(value) > 256 or any(not isinstance(key, str) for key in value):
            raise ValueError("invalid migration JSON object")
        for key, item in value.items():
            _bounded(key, depth + 1)
            _bounded(item, depth + 1)
    elif isinstance(value, list):
        if len(value) > 256:
            raise ValueError("migration JSON array exceeds bound")
        for item in value:
            _bounded(item, depth + 1)
    elif isinstance(value, str):
        if len(value) > 4096 or any(ord(c) < 32 or ord(c) == 127 for c in value):
            raise ValueError("invalid migration JSON string")
    elif value is not None and type(value) not in (bool, int):
        raise ValueError("invalid migration JSON value")


def _encode(value):
    _bounded(value)
    raw = (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()
    if len(raw) > MAX_BYTES:
        raise ValueError("migration record exceeds bound")
    return raw


def _private_record(info):
    if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid()
            or stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1
            or not 0 < info.st_size <= MAX_BYTES):
        raise ValueError("unsafe migration record")


def _read(path):
    _directory(path.parent)
    try:
        expected = path.lstat()
        _private_record(expected)
    except FileNotFoundError as exc:
        raise ValueError("missing permanent migration record") from exc
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as file:
        before = os.fstat(file.fileno())
        _private_record(before)
        if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) != (
                expected.st_dev, expected.st_ino, expected.st_size, expected.st_mtime_ns, expected.st_ctime_ns):
            raise ValueError("migration record replaced before open")
        raw = file.read(MAX_BYTES + 1)
        after = os.fstat(file.fileno())
        if (len(raw) != before.st_size or len(raw) > MAX_BYTES
                or (after.st_size, after.st_mtime_ns, after.st_ctime_ns)
                != (before.st_size, before.st_mtime_ns, before.st_ctime_ns)):
            raise ValueError("migration record changed during read")
    try:
        value = json.loads(raw, object_pairs_hook=_unique, parse_constant=_nonfinite)
    except (UnicodeError, RecursionError) as exc:
        raise ValueError("invalid migration JSON encoding") from exc
    _bounded(value)
    if not isinstance(value, dict):
        raise ValueError("migration record must be an object")
    return value, hashlib.sha256(raw).hexdigest()


def _write_once(directory, name, value):
    raw = _encode(value)
    _directory(directory)
    fd = os.open(directory / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL
                 | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
    # Retain even truncated/uncertain output on every failure; never unlink.
    with os.fdopen(fd, "wb") as file:
        file.write(raw)
        file.flush()
        os.fsync(file.fileno())
    _sync_directory(directory)
    return directory / name


def _candidate(evidence):
    if not isinstance(evidence, dict) or not CANDIDATE_FIELDS.issubset(evidence):
        raise ValueError("incomplete issuer candidate binding")
    match = ENTRY.fullmatch(evidence["entry_id"]) if isinstance(evidence["entry_id"], str) else None
    if (not match or match[1] != evidence["sha256"]
            or not isinstance(evidence["closure"], str) or not CLOSURE.fullmatch(evidence["closure"])
            or not isinstance(evidence["pcr_key_fingerprint"], str)
            or not HASH.fullmatch(evidence["pcr_key_fingerprint"])):
        raise ValueError("invalid issuer candidate binding")
    return {field: evidence[field] for field in CANDIDATE_FIELDS}


def _evidence(kind, evidence, first=None):
    if not isinstance(evidence, dict) or not evidence:
        raise ValueError("migration phase evidence must be nonempty")
    _encode(evidence)
    if kind in {"issuer", "enrollment"}:
        candidate = _candidate(evidence)
        if first is not None and candidate != _candidate(first):
            raise ValueError(f"{kind} candidate binding changed")


def read_operation(operation: Path) -> dict:
    """Bounded read-only diagnosis; returned protected contents are not stdout."""
    kind = operation.name
    if kind not in PHASES or operation.parent.name != "migrations":
        raise ValueError("invalid migration operation path")
    state, root = operation.parent.parent, operation.parent
    for path in (state, root, operation):
        _directory(path)
    attempt, previous = _read(operation / "attempt.json")
    if (set(attempt) != {"version", "kind", "before", "state_binding", "operation_binding"}
            or type(attempt["version"]) is not int or attempt["version"] != 1
            or attempt["kind"] != kind or attempt["state_binding"] != _binding(state)
            or attempt["operation_binding"] != _binding(operation)
            or not isinstance(attempt["before"], dict)
            or type(attempt["before"].get("version")) is not int
            or attempt["before"]["version"] != 1):
        raise ValueError("invalid migration intent binding")
    files = sorted(operation.iterdir())
    if len(files) > len(PHASES[kind]) + len(ASSETS) + 2:
        raise ValueError("unexpected migration artifacts")
    receipts = []
    for path in files:
        if path.name == "attempt.json" or (kind == "issuer" and path.name == "commit-attempt.json"):
            continue
        if path.name in ASSETS:
            _directory(path)
            continue
        index = len(receipts) + 1
        if index > len(PHASES[kind]) or path.name != f"{index:04d}-{PHASES[kind][index - 1]}.json":
            raise ValueError("missing or unexpected migration phase")
        value, digest = _read(path)
        if (set(value) != {"version", "kind", "sequence", "phase", "previous_sha256", "evidence"}
                or type(value["version"]) is not int or value["version"] != 1
                or value["kind"] != kind or type(value["sequence"]) is not int
                or value["sequence"] != index or value["phase"] != PHASES[kind][index - 1]
                or value["previous_sha256"] != previous):
            raise ValueError("invalid migration phase binding")
        _evidence(kind, value["evidence"], receipts[0]["evidence"] if receipts else None)
        receipts.append(value)
        previous = digest
    marker = operation / "commit-attempt.json"
    if marker.exists() or marker.is_symlink():
        value, _ = _read(marker)
        if (kind != "issuer" or not receipts
                or set(value) != {"version", "operation_binding", "prepared_sha256"}
                or type(value["version"]) is not int or value["version"] != 1
                or value["operation_binding"] != _binding(operation)
                or value["prepared_sha256"] != _read(operation / "0001-prepared.json")[1]):
            raise ValueError("invalid permanent commit attempt binding")
    return {**attempt, "phase": receipts[-1]["phase"] if receipts else "intent", "receipts": receipts}


def _operations(state):
    _directory(state)
    root = state / "migrations"
    if not root.exists() and not root.is_symlink():
        return []
    _directory(root)
    children = list(root.iterdir())
    if len(children) > len(PHASES) or any(path.name not in PHASES for path in children):
        raise ValueError("unexpected migration operation")
    return [read_operation(path) for path in sorted(children)]


_PERMIT_KEY = object()


@dataclass
class _PublicationPermit:
    operation: Path
    state_binding: dict
    evidence: dict
    marker_sha256: str
    authority: object = field(repr=False)
    used: bool = False


def _publication_permit(state: Path, operation: Path):
    """Internal one-call permit; a permanent marker alone is never a resume API."""
    current = read_operation(operation)
    if operation != state / "migrations/issuer" or current["phase"] != "exchanged":
        raise ValueError("maintenance publication requires the exact exchanged operation")
    marker = _read(operation / "commit-attempt.json")[1]
    return _PublicationPermit(operation, _binding(state), _candidate(current["receipts"][-1]["evidence"]), marker, _PERMIT_KEY)


def require_publication_allowed(state, candidate, permit=None):
    if permit is None:
        require_writer_allowed(state, "install")
        return
    if (type(permit) is not _PublicationPermit or permit.authority is not _PERMIT_KEY
            or permit.used or permit.state_binding != _binding(state)
            or permit.operation != state / "migrations/issuer"):
        raise ValueError("invalid or consumed maintenance publication permit")
    current = read_operation(permit.operation)
    evidence = {"entry_id": candidate.entry_id, "closure": str(candidate.generation.closure),
                "sha256": candidate.image_sha256, "pcr_key_fingerprint": candidate.pcr_key_fingerprint}
    if (current["phase"] != "exchanged" or _candidate(evidence) != permit.evidence
            or _candidate(current["receipts"][-1]["evidence"]) != permit.evidence
            or _read(permit.operation / "commit-attempt.json")[1] != permit.marker_sha256):
        raise ValueError("maintenance publication permit binding changed")
    permit.used = True


def recovery_records(state: Path) -> dict:
    """Permanent issuer manual-recovery pins; completion never releases them.

    No release command exists in this migration. Generic fixture intents without
    a publication baseline have no image pin; real commit requires that baseline.
    """
    from .publish import validate_manifest
    records = {}
    for operation in _operations(state):
        if operation["kind"] != "issuer" or "publication" not in operation["before"]:
            continue
        manifest = validate_manifest(operation["before"]["publication"])
        entry = manifest["known_good"]
        if entry is not None:
            records[entry] = dict(manifest["images"][entry])
    return records


def begin_operation(state: Path, kind: str, before: dict) -> Path:
    """Permanent intent once per migration kind; caller holds installer_lock."""
    if kind not in PHASES or not isinstance(before, dict) or type(before.get("version")) is not int or before["version"] != 1:
        raise ValueError("invalid migration kind or baseline")
    _encode(before)
    operations = _operations(state)
    if any(value["kind"] == kind or value["phase"] != "complete" for value in operations):
        raise ValueError("migration attempt already exists or is unfinished")
    root = state / "migrations"
    if not root.exists():
        root.mkdir(mode=0o700)
        _sync_directory(state)
    operation = root / kind
    operation.mkdir(mode=0o700)
    _sync_directory(root)
    _write_once(operation, "attempt.json", {
        "version": 1, "kind": kind, "before": before,
        "state_binding": _binding(state), "operation_binding": _binding(operation),
    })
    return operation


def record_phase(operation: Path, phase: str, evidence: dict) -> Path:
    """Append a bound receipt once; not a resumable physical-operation command."""
    current = read_operation(operation)
    kind, index = current["kind"], len(current["receipts"])
    if index >= len(PHASES[kind]) or phase != PHASES[kind][index]:
        raise ValueError("invalid migration phase transition")
    _evidence(kind, evidence, current["receipts"][0]["evidence"] if index else None)
    previous = operation / (f"{index:04d}-{PHASES[kind][index - 1]}.json" if index else "attempt.json")
    _, digest = _read(previous)
    return _write_once(operation, f"{index + 1:04d}-{phase}.json", {
        "version": 1, "kind": kind, "sequence": index + 1,
        "phase": phase, "previous_sha256": digest, "evidence": evidence,
    })


def require_confirmation_binding(state: Path, loaded_entry: str, record: dict) -> None:
    """Actual confirmation matches the protected signed candidate, not just manifest."""
    require_writer_allowed(state, "confirm-boot", loaded_entry)
    pending = [value for value in _operations(state) if value["phase"] != "complete"]
    if pending:
        if not isinstance(record, dict):
            raise ValueError("invalid migration confirmation record")
        expected = _candidate(pending[0]["receipts"][-1]["evidence"])
        if _candidate({**record, "entry_id": loaded_entry}) != expected:
            raise ValueError("migration confirmation binding changed")


def require_writer_allowed(state: Path, action: str, loaded_entry: str | None = None) -> None:
    """Legacy absence permits ordinary work; unfinished/unknown state fails closed.

    A durably published issuer or verified enrollment permits exact-candidate
    confirmation, never publication/cleanup/pruning. Actual boot/hash/closure/
    readiness checks remain the publisher's responsibility. No migration is
    completed here; HUMAN attended enrollment acceptance remains separate.
    """
    if action not in ACTIONS:
        raise ValueError("unsupported migration writer action")
    pending = [value for value in _operations(state) if value["phase"] != "complete"]
    if not pending:
        return
    if (len(pending) == 1 and action == "confirm-boot"
            and (pending[0]["kind"], pending[0]["phase"]) in {
                ("issuer", "published"), ("enrollment", "token-verified")}
            and loaded_entry == pending[0]["receipts"][-1]["evidence"]["entry_id"]):
        return
    raise ValueError("unfinished migration blocks writer")
