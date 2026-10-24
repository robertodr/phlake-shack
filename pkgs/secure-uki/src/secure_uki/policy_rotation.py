"""Software-only issuer preparation and atomic whole-directory primitive.

No production command is exposed here. A future maintenance entry point must
verify the exact Dancer runtime/encrypted binds before calling prepare_rotation.
It owns installer_lock across preparation. The exchange primitive requires its
caller to hold that same lock and a durable operation intent; it never authorizes
replay, publication, boot selection or hardware changes. Readers must hold the
lock or pin a directory fd: two separate pathname reads can straddle any swap.
"""

from dataclasses import replace
import ctypes
import hashlib
import os
from pathlib import Path
import re
import shutil
import stat

from . import migration_state as migration
from .filesystem_identity import filesystem_identity
from .metadata import Generation, Keys, PreparedImage, Run, Tools, read_generation
from .prepare import OPENSSL, _key_consistency, _verified_sections, prepare_image
from .publish import _image_hash, _install_locked, _verify_pe, _verify_retained, installer_lock, load_manifest

PAIR_FILES = {"private.pem": 0o600, "public.pem": 0o644}
MAX_PEM = 16384


def _immutable_source(path, info):
    # Nix legitimately deduplicates immutable public source with hardlinks.
    # This exception never applies to mode-bound private/pair/state artifacts.
    return (path.is_absolute() and path.is_relative_to('/nix/store')
            and not any(part in {'.', '..'} for part in path.parts)
            and stat.S_ISREG(info.st_mode) and info.st_uid == 0
            and not info.st_mode & 0o222 and info.st_nlink >= 1)


def _read_file(path, mode=None, *, sync=False, max_size=None):
    expected = path.lstat()
    shared_source = mode is None and _immutable_source(path, expected)
    if (not stat.S_ISREG(expected.st_mode) or (expected.st_nlink != 1 and not shared_source)
            or (mode is not None and (stat.S_IMODE(expected.st_mode) != mode or expected.st_uid != os.geteuid()))
            or (max_size is not None and not 0 < expected.st_size <= max_size)):
        raise ValueError("unsafe rotation input file")
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    with os.fdopen(fd, "rb") as file:
        before = os.fstat(file.fileno())
        if (not stat.S_ISREG(before.st_mode)
                or (before.st_nlink != 1 and not (shared_source and _immutable_source(path, before)))
                or (before.st_uid, before.st_mode) != (expected.st_uid, expected.st_mode)):
            raise ValueError('rotation input ownership/mode/link changed before read')
        if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) != (
                expected.st_dev, expected.st_ino, expected.st_size, expected.st_mtime_ns, expected.st_ctime_ns):
            raise ValueError("rotation input replaced before read")
        filesystem = filesystem_identity(file.fileno())
        digest = hashlib.file_digest(file, "sha256").hexdigest()
        after = os.fstat(file.fileno())
        if (after.st_size, after.st_mtime_ns, after.st_ctime_ns) != (
                before.st_size, before.st_mtime_ns, before.st_ctime_ns):
            raise ValueError("rotation input changed during read")
        if sync:
            os.fsync(file.fileno())
    return {"filesystem": filesystem, "inode": before.st_ino, "size": before.st_size,
            "mode": stat.S_IMODE(before.st_mode), "sha256": digest}


def _pair_snapshot(path, *, sync=False):
    binding = migration._binding(path)
    if {child.name for child in path.iterdir()} != set(PAIR_FILES):
        raise ValueError("rotation pair directory contains unexpected entries")
    files = {name: _read_file(path / name, mode, sync=sync, max_size=MAX_PEM) for name, mode in PAIR_FILES.items()}
    if sync:
        migration._sync_directory(path)
    return {"directory": binding, "files": files}


def _rename_exchange(active, staged):
    """One kernel operation using pinned parent fds; no compatibility fallback."""
    libc = ctypes.CDLL(None, use_errno=True)
    try:
        rename = libc.renameat2
    except AttributeError as exc:
        raise OSError("atomic exchange is unavailable") from exc
    rename.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    rename.restype = ctypes.c_int
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
    a_fd = os.open(active.parent, flags)
    try:
        b_fd = os.open(staged.parent, flags)
        try:
            if rename(a_fd, os.fsencode(active.name), b_fd, os.fsencode(staged.name), 2) != 0:
                raise OSError(ctypes.get_errno(), "atomic directory exchange unavailable or failed")
        finally:
            os.close(b_fd)
    finally:
        os.close(a_fd)


def _exchange_paths(active, staged):
    for path in (active, staged, active.parent, staged.parent):
        migration._directory(path)
    if (active == staged or active.is_relative_to(staged) or staged.is_relative_to(active)
            or active.stat().st_dev != staged.stat().st_dev):
        raise ValueError("atomic exchange requires distinct same-filesystem directories")


def atomic_pair_exchange(active: Path, staged: Path) -> None:
    """Swap real complete directories once; uncertainty never triggers rollback.

    The caller owns intent/lock and must retain both locations after any failure.
    This filesystem primitive does not cryptographically validate PEMs; preparation
    and future commit validate/bind the actual pairs before invoking it.
    """
    _exchange_paths(active, staged)
    before_active = _pair_snapshot(active, sync=True)
    before_staged = _pair_snapshot(staged, sync=True)
    parents = {active.parent, staged.parent}
    for parent in sorted(parents):
        migration._sync_directory(parent)
    _rename_exchange(active, staged)
    for directory in (active, staged, *sorted(parents)):
        migration._sync_directory(directory)
    if _pair_snapshot(active) != before_staged or _pair_snapshot(staged) != before_active:
        raise ValueError("atomic pair exchange identity changed; no automatic restoration")


def _probe_exchange(artifacts, active):
    """Probe only newly owned empty directories on the pair's filesystem."""
    left, right = artifacts / "exchange-probe-a", artifacts / "exchange-probe-b"
    for path in (left, right):
        path.mkdir(mode=0o700)
    if left.stat().st_dev != active.stat().st_dev:
        raise ValueError("staging and active pair use different filesystems")
    a, b = migration._binding(left), migration._binding(right)
    migration._sync_directory(artifacts)
    _rename_exchange(left, right)
    migration._sync_directory(left)
    migration._sync_directory(right)
    migration._sync_directory(artifacts)
    if migration._binding(left) != b or migration._binding(right) != a:
        raise ValueError("atomic exchange probe identity mismatch")


def _generation_snapshot(generation):
    if not isinstance(generation, Generation) or not migration.CLOSURE.fullmatch(str(generation.closure)):
        raise ValueError("invalid rotation generation closure")
    return {"closure": str(generation.closure), "cmdline": generation.cmdline,
            "generation_id": generation.generation_id, "label": generation.label,
            "components": {name: {"path": str(getattr(generation, name)), **_read_file(getattr(generation, name))}
                           for name in ("kernel", "initrd", "init", "os_release")}}


def _software_runner(tools, run):
    allowed = {OPENSSL, str(tools.ukify), str(tools.measure), str(tools.sbsign), str(tools.sbverify)}
    def software(argv):
        if not argv or argv[0] not in allowed:
            raise ValueError("unsupported software rotation command")
        return run(argv)
    return software


def _bits(public, run):
    text = run([OPENSSL, "pkey", "-pubin", "-in", str(public), "-text", "-noout"])
    match = re.search(r"Public-Key: \((\d+) bit\)", text)
    if not match:
        raise ValueError("invalid software RSA issuer")
    return int(match[1])


def _new_file(path, mode):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC, mode)
    os.close(fd)


def prepare_rotation(generation: Generation, tools: Tools, keys: Keys, state: Path, run: Run, *, guard=None) -> Path:
    """Stage/verify software2048 candidate, never exchange/publish/enroll.

    Encrypted mounts and exact accepted runtime/source are caller prerequisites;
    this not-yet-exposed library validates owner-only files and source identities.
    Any failure retains operation intent and all staged pair/evidence directories.
    No restart/retry/cleanup command is provided. Protected receipts are not stdout.
    """
    software = _software_runner(tools, run)
    with installer_lock(state):
        migration.require_writer_allowed(state, "install")
        if (state / "journal.json").exists() or (state / "journal.json").is_symlink():
            raise ValueError("rotation refuses pending publication")
        active = state / "pcr-signing"
        if keys.pcr_private != active / "private.pem" or keys.pcr_public != active / "public.pem":
            raise ValueError("rotation requires the fixed active pair directory")
        approval = guard('prepare') if guard is not None else None
        before = _pair_snapshot(active)
        source = _generation_snapshot(generation)
        db = {name: _read_file(getattr(keys, name)) for name in ("db_key", "db_cert")}
        operation = migration.begin_operation(state, "issuer", {
            "version": 1, "active_pair": before, "source": source, "db": db,
            "publication": load_manifest(state), "boot_id": _boot_id(), "maintenance": approval,
        })
        artifacts = operation / "artifacts"
        artifacts.mkdir(mode=0o700)
        migration._sync_directory(operation)
        _probe_exchange(artifacts, active)
        old_check = artifacts / "old-key-check"
        old_check.mkdir(mode=0o700)
        old_fingerprint = _key_consistency(keys, old_check, software)
        if _bits(keys.pcr_public, software) != 3072:
            raise ValueError("rotation baseline must be software RSA3072")
        staged = operation / "staged-pair"
        staged.mkdir(mode=0o700)
        migration._sync_directory(operation)
        new_private, new_public = staged / "private.pem", staged / "public.pem"
        _new_file(new_private, 0o600)
        _new_file(new_public, 0o600)
        software([OPENSSL, "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048", "-out", str(new_private)])
        software([OPENSSL, "pkey", "-in", str(new_private), "-pubout", "-out", str(new_public)])
        new_public.chmod(0o644)
        _pair_snapshot(staged, sync=True)
        staged_keys = replace(keys, pcr_private=new_private, pcr_public=new_public)
        new_check = artifacts / "new-key-check"
        new_check.mkdir(mode=0o700)
        new_fingerprint = _key_consistency(staged_keys, new_check, software)
        if _bits(new_public, software) != 2048:
            raise ValueError("new issuer must be software RSA2048")
        candidate = prepare_image(generation, artifacts, tools, staged_keys, software, retain_failed=True)
        _read_file(candidate.path, 0o600, sync=True)
        migration._sync_directory(candidate.path.parent)
        migration._sync_directory(artifacts)
        if (_pair_snapshot(active) != before or _generation_snapshot(generation) != source
                or {name: _read_file(getattr(keys, name)) for name in ("db_key", "db_cert")} != db):
            raise ValueError("rotation baseline changed during preparation")
        if guard is not None:
            if guard('prepare') != approval:
                raise ValueError('accepted maintenance approval changed during preparation')
        migration.record_phase(operation, "prepared", {
            "entry_id": candidate.entry_id, "closure": str(generation.closure),
            "sha256": candidate.image_sha256, "pcr_key_fingerprint": candidate.pcr_key_fingerprint,
            "candidate_path": str(candidate.path), "old_fingerprint": old_fingerprint,
            "active_pair": before, "staged_pair": _pair_snapshot(staged),
            "new_fingerprint": new_fingerprint,
        })
        return operation


def _boot_id():
    # Protected binding only; never output unique boot identifiers.
    value = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
    if not value:
        raise ValueError("current boot identity is unavailable")
    return value


def _rotation_operation(operation, state, phase):
    if operation != state / "migrations/issuer":
        raise ValueError("rotation requires the fixed issuer operation")
    current = migration.read_operation(operation)
    if current["phase"] != phase:
        raise ValueError("rotation operation is not at the required one-shot phase")
    return current


def commit_rotation(operation: Path, generation: Generation, tools: Tools,
                    keys: Keys, esp: Path, state: Path, run: Run, *, guard=None) -> dict:
    """One-shot exchange + native verified publication; no confirmation/replay.

    Runtime/mount/trust/header approval checks are future entry-point prerequisites.
    The permanent commit attempt precedes even verification scratch writes. Unknown
    outcome retains whole pairs, original recovery and publication journal.
    """
    with installer_lock(state):
        current = _rotation_operation(operation, state, "prepared")
        if guard is not None:
            guard('commit')
        before, evidence = current["before"], current["receipts"][0]["evidence"]
        active, staged = state / "pcr-signing", operation / "staged-pair"
        if (keys.pcr_private != active / "private.pem" or keys.pcr_public != active / "public.pem"
                or _pair_snapshot(active) != evidence["active_pair"]
                or _pair_snapshot(staged) != evidence["staged_pair"]
                or _generation_snapshot(generation) != before["source"]
                or {name: _read_file(getattr(keys, name)) for name in ("db_key", "db_cert")} != before["db"]
                or load_manifest(state) != before["publication"]
                or before["publication"]["known_good"] is None):
            raise ValueError("rotation baseline or recovery changed before commit")
        if (state / "journal.json").exists() or (state / "journal.json").is_symlink():
            raise ValueError("rotation cannot replay pending publication")
        candidate_path = Path(evidence["candidate_path"])
        if (not candidate_path.is_relative_to(operation / "artifacts")
                or candidate_path.resolve(strict=True) != candidate_path
                or _read_file(candidate_path, 0o600)["sha256"] != evidence["sha256"]):
            raise ValueError("prepared rotation candidate changed")
        marker = operation / "commit-attempt.json"
        if marker.exists() or marker.is_symlink():
            raise ValueError("permanent rotation commit attempt already exists; no retry")
        migration._write_once(operation, "commit-attempt.json", {
            "version": 1, "operation_binding": migration._binding(operation),
            "prepared_sha256": migration._read(operation / "0001-prepared.json")[1],
        })
        scratch = operation / "artifacts/commit-check"
        scratch.mkdir(mode=0o700)
        migration._sync_directory(scratch.parent)
        staged_keys = replace(keys, pcr_private=staged / "private.pem", pcr_public=staged / "public.pem")
        fingerprint = _key_consistency(staged_keys, scratch, run)
        if fingerprint != evidence["pcr_key_fingerprint"] or _bits(staged_keys.pcr_public, run) != 2048:
            raise ValueError("staged issuer changed before exchange")
        _verify_pe(candidate_path, tools, keys, run)
        _verified_sections(candidate_path, generation, staged_keys, scratch, tools, fingerprint, run)
        _verify_retained(before["publication"], esp, tools, keys, run, state)
        # Peak-space refusal before pair exchange; publisher checks again before ESP writes.
        manager = tools.bootctl.resolve().parent.parent / "lib/systemd/boot/efi/systemd-bootx64.efi"
        if shutil.disk_usage(esp).free < candidate_path.stat().st_size + 4 * manager.stat().st_size + 1024 * 1024:
            raise OSError("insufficient peak ESP space before rotation")
        if guard is not None:
            guard('commit')
        atomic_pair_exchange(active, staged)
        migration.record_phase(operation, "exchanged", evidence)
        candidate = PreparedImage(generation, candidate_path, evidence["sha256"], fingerprint, evidence["entry_id"])
        permit = migration._publication_permit(state, operation)
        result = _install_locked(candidate, esp, state, tools, keys, run, maintenance=permit)
        if guard is not None:
            guard('published')
        migration.record_phase(operation, "published", evidence)
        return result


def accept_rotation(operation: Path, loaded_entry: str, booted_closure: Path,
                    esp: Path, state: Path, run: Run, *, tools: Tools, keys: Keys,
                    manual_unlock_attested: bool, guard=None) -> Path:
    """Accept exact already-confirmed new boot, never manufacture confirmation.

    Caller explicitly attests its attended manual unlock. No automatic restart,
    publication, key switch or independent off-host backup verification is inferred.
    Backup verification is a separate later human gate, not fabricated by this API.
    """
    with installer_lock(state):
        current = _rotation_operation(operation, state, "published")
        if guard is not None:
            guard('accept')
        before, evidence = current["before"], current["receipts"][-1]["evidence"]
        if manual_unlock_attested is not True or _boot_id() == before["boot_id"]:
            raise ValueError("rotation requires an attended manual unlock on a new boot")
        manifest = load_manifest(state)
        if (loaded_entry != evidence["entry_id"] or str(booted_closure) != evidence["closure"]
                or manifest["default"] != loaded_entry or manifest["known_good"] != loaded_entry
                or (state / "journal.json").exists() or (state / "journal.json").is_symlink()):
            raise ValueError("rotation has not been confirmed on the exact new image")
        if run(["bootctl", f"--esp-path={esp}", "--print-stub-path"]).strip() != str(esp / "EFI/Linux" / loaded_entry):
            raise ValueError("actual loaded rotation image differs")
        migration.require_confirmation_binding(state, loaded_entry, manifest["images"][loaded_entry])
        for field, expected in (("ActiveState", "active"), ("SubState", "exited"), ("Result", "success"), ("ExecMainStatus", "0")):
            if run(["systemctl", "show", "secure-uki-confirm", "-p", field, "--value"]).strip() != expected:
                raise ValueError("actual boot confirmation has not succeeded")
        if (_pair_snapshot(state / "pcr-signing") != evidence["staged_pair"]
                or _pair_snapshot(operation / "staged-pair") != evidence["active_pair"]
                or {name: _read_file(getattr(keys, name)) for name in ("db_key", "db_cert")} != before["db"]):
            raise ValueError("retained issuer or Secure Boot pair changed")
        scratch = operation / "artifacts/accept-check"
        scratch.mkdir(mode=0o700)
        fingerprint = _key_consistency(keys, scratch, run)
        if fingerprint != evidence["pcr_key_fingerprint"] or _bits(keys.pcr_public, run) != 2048:
            raise ValueError("current issuer differs from published rotation")
        image = esp / "EFI/Linux" / loaded_entry
        if _image_hash(image) != evidence["sha256"]:
            raise ValueError("published rotation image changed")
        _verify_pe(image, tools, keys, run)
        _verified_sections(image, read_generation(booted_closure), keys, scratch, tools, fingerprint, run)
        if guard is not None:
            guard('accept')
        migration.record_phase(operation, "manual-boot-accepted", evidence)
        return migration.record_phase(operation, "complete", evidence)
