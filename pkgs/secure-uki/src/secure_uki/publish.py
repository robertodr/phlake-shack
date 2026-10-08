"""Durable versioned state for recoverable publication.

Installer entry points remain disabled until the transaction is verified.
"""

from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import tempfile

from .metadata import PreparedImage
from .prepare import _key_consistency, _verified_sections

ENTRY = re.compile(r"dancer-([0-9a-f]{64})\.efi")
HASH = re.compile(r"[0-9a-f]{64}")
CLOSURE = re.compile(r"/nix/store/[0123456789abcdfghijklmnpqrsvwxyz]{32}-[A-Za-z0-9+._?=-]+")


def _entry_digest(entry: object) -> str:
    match = ENTRY.fullmatch(entry) if isinstance(entry, str) else None
    if not match:
        raise ValueError("invalid managed UKI identity")
    return match[1]


def validate_manifest(manifest: dict) -> dict:
    """Validate v1 without interpreting compatible extra fields as settings.

    Closure validation is lexical here: reading state must not conceal a lost
    closure. Installation/confirmation must separately verify its availability.
    """
    if (not isinstance(manifest, dict) or type(manifest.get("version")) is not int
            or manifest["version"] != 1):
        raise ValueError("unsupported manifest version")
    if not {"default", "known_good", "images"}.issubset(manifest):
        raise ValueError("incomplete manifest")
    images = manifest["images"]
    if not isinstance(images, dict):
        raise ValueError("manifest images must be an object")
    for entry, record in images.items():
        digest = _entry_digest(entry)
        if not isinstance(record, dict) or record.get("sha256") != digest:
            raise ValueError("image identity does not match its recorded SHA256")
        closure, fingerprint = record.get("closure"), record.get("pcr_key_fingerprint")
        if not isinstance(closure, str) or not CLOSURE.fullmatch(closure):
            raise ValueError("invalid retained closure path")
        if not isinstance(fingerprint, str) or not HASH.fullmatch(fingerprint):
            raise ValueError("invalid policy key fingerprint")
        manager = record.get("bootmanager_sha256")
        if manager is not None and (not isinstance(manager, str) or not HASH.fullmatch(manager)):
            raise ValueError("invalid retained manager identity")
    for field in ("default", "known_good"):
        entry = manifest[field]
        if entry is not None:
            _entry_digest(entry)
            if entry not in images:
                raise ValueError("boot reference has no retained image")
    return manifest


def _private_directory(path: Path) -> None:
    stat = path.stat()
    if path.is_symlink() or not path.is_dir() or stat.st_uid != os.geteuid() or stat.st_mode & 0o077:
        raise ValueError("state directory must be owner-only")
    if path.resolve().is_relative_to(Path("/nix/store")):
        raise ValueError("mutable state must not reside in the Nix store")


def _private_regular(path: Path) -> None:
    if path.is_symlink() or not path.is_file():
        raise ValueError("managed state must be a regular file")
    stat = path.stat()
    if stat.st_uid != os.geteuid() or stat.st_mode & 0o077:
        raise ValueError("managed state must be owner-only")


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate state JSON key")
        result[key] = value
    return result


def load_manifest(state_dir: Path) -> dict:
    _private_directory(state_dir)
    path = state_dir / "manifest.json"
    if path.is_symlink():
        raise ValueError("managed state must not be a symlink")
    if not path.exists():
        return {"version": 1, "default": None, "known_good": None, "images": {}}
    _private_regular(path)
    return validate_manifest(json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_unique_object))


def _write_json(state_dir: Path, name: str, value: dict) -> None:
    """Same-directory replacement; durable file first, directory afterward.

    A failure after rename may leave the new state in place. Transaction callers
    must retain their journal/closures until that uncertainty is reconciled.
    """
    _private_directory(state_dir)
    path = state_dir / name
    if path.exists() or path.is_symlink():
        _private_regular(path)
    data = (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")
    fd, filename = tempfile.mkstemp(prefix=f".{name}-", dir=state_dir)
    temporary = Path(filename)
    try:
        with os.fdopen(fd, "wb") as file:
            file.write(data)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary, path)
        directory_fd = os.open(state_dir, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        temporary.unlink(missing_ok=True)


@contextmanager
def installer_lock(state_dir: Path):
    """One nonblocking lock shared by install, reconciliation and confirmation.

    The inode remains in place: unlinking it would permit concurrent lock domains.
    CLOEXEC prevents a signing child from retaining ownership after installer exit.
    """
    _private_directory(state_dir)
    path = state_dir / "installer.lock"
    fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
    try:
        _private_regular(path)
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            yield
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
    finally:
        os.close(fd)


def _flush_directory(directory: Path) -> None:
    fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def _image_hash(path: Path) -> str:
    import hashlib
    if path.is_symlink() or not path.is_file():
        raise ValueError("boot artifact must be a regular file")
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _verify_pe(path, tools, keys, run):
    run([str(tools.sbverify), "--cert", str(keys.db_cert), str(path)])


def _publish_file(source, destination, tools, keys, run, *, immutable=False):
    destination.parent.mkdir(parents=True, exist_ok=True)
    digest = _image_hash(source)
    if destination.exists() or destination.is_symlink():
        if destination.is_symlink() or not destination.is_file():
            raise ValueError("unsafe ESP artifact")
        if immutable:
            if _image_hash(destination) != digest:
                raise ValueError("immutable artifact identity collision")
            _verify_pe(destination, tools, keys, run)
            return
    fd, filename = tempfile.mkstemp(prefix=".publish-", dir=destination.parent)
    temporary = Path(filename)
    try:
        with os.fdopen(fd, "wb") as output, source.open("rb") as input_file:
            shutil.copyfileobj(input_file, output)
            output.flush()
            os.fsync(output.fileno())
        if _image_hash(temporary) != digest:
            raise ValueError("ESP copy differs from verified source")
        _verify_pe(temporary, tools, keys, run)
        os.replace(temporary, destination)
        _flush_directory(destination.parent)
    finally:
        temporary.unlink(missing_ok=True)


def _pin(manifest, state_dir, tools, run):
    directory = state_dir / "gc-roots"
    directory.mkdir(mode=0o700, exist_ok=True)
    _private_directory(directory)
    for entry in {manifest["default"], manifest["known_good"]} - {None}:
        root = directory / entry
        closure = manifest["images"][entry]["closure"]
        if ((root.exists() or root.is_symlink())
                and (not root.is_symlink() or str(root.readlink()) != closure)):
            raise ValueError("unexpected GC root")
        # A link alone proves neither closure availability nor registration in
        # Nix's indirect root directory. Reassert both, including retained roots.
        run([str(tools.nix_store), "--realise", closure, "--add-root", str(root), "--indirect"])
        if not root.is_symlink() or str(root.readlink()) != closure:
            raise ValueError("Nix did not create the expected closure root")
    _flush_directory(directory)


def _select(entry, esp, tools, run):
    _entry_digest(entry)
    conf = esp / "loader/loader.conf"
    if conf.is_symlink():
        raise ValueError("unsafe loader.conf")
    lines = conf.read_text().splitlines() if conf.exists() else []
    lines = [line for line in lines if not line.split() or line.split()[0] not in {"default", "editor"}]
    data = ("\n".join([*lines, f"default {entry}", "editor no"]) + "\n").encode()
    conf.parent.mkdir(parents=True, exist_ok=True)
    fd, filename = tempfile.mkstemp(prefix=".loader-", dir=conf.parent)
    temporary = Path(filename)
    try:
        with os.fdopen(fd, "wb") as file:
            file.write(data)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary, conf)
        _flush_directory(conf.parent)
        # Firmware variables outrank loader.conf. Remove one-shot precedence,
        # then select the exact same immutable entry persistently, last.
        run([str(tools.bootctl), f"--esp-path={esp}", "set-oneshot", ""])
        run([str(tools.bootctl), f"--esp-path={esp}", "set-default", entry])
    finally:
        temporary.unlink(missing_ok=True)


def _manager_backup(record, esp):
    digest = record.get("bootmanager_sha256")
    if not isinstance(digest, str) or not HASH.fullmatch(digest):
        raise ValueError("retained boot manager association is unknown; no unsafe recovery")
    path = esp / "EFI/secure-uki" / f"systemd-boot-{digest}.efi"
    if _image_hash(path) != digest:
        raise ValueError("retained signed manager backup is unavailable")
    return path


def _restore_manager(manifest, esp, tools, keys, run):
    backup = _manager_backup(manifest["images"][manifest["default"]], esp)
    _verify_pe(backup, tools, keys, run)
    for destination in (esp / "EFI/systemd/systemd-bootx64.efi", esp / "EFI/BOOT/BOOTX64.EFI"):
        _publish_file(backup, destination, tools, keys, run)


def _verify_retained(manifest, esp, tools, keys, run):
    for entry in {manifest["default"], manifest["known_good"]} - {None}:
        path = esp / "EFI/Linux" / entry
        if _image_hash(path) != manifest["images"][entry]["sha256"]:
            raise ValueError("retained image identity is unavailable")
        _verify_pe(path, tools, keys, run)
        _verify_pe(_manager_backup(manifest["images"][entry], esp), tools, keys, run)


def _prune(manifest, esp, state_dir):
    """Only after a durable, unambiguous selection and journal removal.

    Scan the installer's namespace, not just indexed records: interrupted first
    installs or signed-byte changes can otherwise leak unindexed images/roots.
    Never touch unrelated owner files or historical archives outside this namespace.
    """
    if (state_dir / "journal.json").exists():
        raise ValueError("cannot prune during ambiguous publication")
    keep = {manifest["default"], manifest["known_good"]} - {None}
    for image in (esp / "EFI/Linux").iterdir():
        if ENTRY.fullmatch(image.name) and image.name not in keep:
            if image.is_symlink() or not image.is_file():
                raise ValueError("unsafe managed image")
            image.unlink()
    roots = state_dir / "gc-roots"
    _private_directory(roots)
    for root in roots.iterdir():
        if ENTRY.fullmatch(root.name) and root.name not in keep:
            if not root.is_symlink():
                raise ValueError("unsafe managed GC root")
            root.unlink()
    for entry in set(manifest["images"]) - keep:
        del manifest["images"][entry]
    managers = {record["bootmanager_sha256"] for record in manifest["images"].values()}
    for backup in (esp / "EFI/secure-uki").iterdir():
        match = re.fullmatch(r"systemd-boot-([0-9a-f]{64})\.efi", backup.name)
        if match and match[1] not in managers:
            if backup.is_symlink() or not backup.is_file():
                raise ValueError("unsafe managed manager backup")
            backup.unlink()
    for directory in (esp / "EFI/Linux", roots, esp / "EFI/secure-uki"):
        _flush_directory(directory)


def _reconcile(esp, state_dir, tools, keys, run):
    path = state_dir / "journal.json"
    if not path.exists() and not path.is_symlink():
        return
    _private_regular(path)
    journal = json.loads(path.read_text(), object_pairs_hook=_unique_object)
    if not isinstance(journal, dict) or type(journal.get("version")) is not int or journal["version"] != 1:
        raise ValueError("unsupported journal version")
    if not {"before", "after", "old_default", "candidate"}.issubset(journal):
        raise ValueError("incomplete recovery journal")
    before, after = validate_manifest(journal["before"]), validate_manifest(journal["after"])
    _entry_digest(journal["candidate"])
    if (journal["old_default"] != before["default"] or journal["candidate"] != after["default"]
            or before["known_good"] != after["known_good"]
            or any(after["images"].get(entry) != record for entry, record in before["images"].items()
                   if entry != journal["candidate"])):
        raise ValueError("inconsistent recovery journal")
    previous_candidate = before["images"].get(journal["candidate"])
    if previous_candidate and any(previous_candidate[field] != after["images"][journal["candidate"]][field]
                                  for field in ("closure", "sha256", "pcr_key_fingerprint")):
        raise ValueError("recovery candidate identity changed")
    # Reusing the exact UKI may legitimately update its signed manager binding;
    # before still holds the recoverable prior manager until commit/pruning.
    current = load_manifest(state_dir)
    if (current["default"] not in {before["default"], after["default"]}
            or current["known_good"] != before["known_good"]):
        raise ValueError("current state conflicts with recovery journal; refusing to guess")
    # An interrupted first install has no old managed default. Finish forward
    # only if its committed candidate is intact. Otherwise defer publication.
    recover = before if before["default"] is not None else after
    if before["default"] is None:
        if current["default"] is None and current["known_good"] is None:
            # A candidate file alone does not prove signed managers/fallback
            # reached their destinations. Defer selection to the complete
            # publication path, replacing the intent durably before proceeding.
            # Keep the existing journal and never invent a known-good boot.
            return
        if current["default"] != after["default"] or current["known_good"] is not None:
            raise ValueError("ambiguous first-install recovery; refusing to discard state")
    _verify_retained(recover, esp, tools, keys, run)
    _pin(recover, state_dir, tools, run)
    _restore_manager(recover, esp, tools, keys, run)
    _select(recover["default"], esp, tools, run)
    write_manifest(state_dir, recover)
    path.unlink()
    _flush_directory(state_dir)
    _prune(recover, esp, state_dir)
    write_manifest(state_dir, recover)


def install(candidate, esp, state_dir, tools, keys, run) -> dict:
    """Publish only verified signed bytes; never confirm a boot or enroll."""
    with installer_lock(state_dir):
        return _install_locked(candidate, esp, state_dir, tools, keys, run)


def _install_locked(candidate, esp, state_dir, tools, keys, run):
    # CLI holds this same lock across preparation too; public install acquires it
    # for API callers. Neither entry point creates a second lock domain.
    if not isinstance(candidate, PreparedImage) or _entry_digest(candidate.entry_id) != candidate.image_sha256:
        raise ValueError("invalid prepared image contract")
    if _image_hash(candidate.path) != candidate.image_sha256:
        raise ValueError("prepared image changed before publication")
    with tempfile.TemporaryDirectory(prefix=".install-", dir=state_dir) as temp:
        scratch = Path(temp)
        fingerprint = _key_consistency(keys, scratch, run)
        if candidate.pcr_key_fingerprint != fingerprint:
            raise ValueError("prepared image uses a different policy key")
        _verify_pe(candidate.path, tools, keys, run)
        _verified_sections(candidate.path, candidate.generation, keys, scratch, tools, fingerprint, run)
        _reconcile(esp, state_dir, tools, keys, run)
        before = load_manifest(state_dir)
        _verify_retained(before, esp, tools, keys, run)
        source = tools.bootctl.resolve().parent.parent / "lib/systemd/boot/efi/systemd-bootx64.efi"
        manager = scratch / "systemd-boot.efi"
        run([str(tools.sbsign), "--key", str(keys.db_key), "--cert", str(keys.db_cert),
             "--output", str(manager), str(source)])
        _verify_pe(manager, tools, keys, run)
        # Authenticode adds a certificate table, not different executable sections.
        def sections(path):
            info = json.loads(run([str(tools.ukify), "--all", "--json=short", "inspect", str(path)]))
            return {name: (data["size"], data["sha256"]) for name, data in info.items()}
        if sections(source) != sections(manager):
            raise ValueError("signed manager differs from pinned source")
        manager_hash = _image_hash(manager)
        peak = candidate.path.stat().st_size + 4 * manager.stat().st_size + 1024 * 1024
        if shutil.disk_usage(esp).free < peak:
            raise OSError("insufficient peak ESP space; refusing to prune for staging")
        after = json.loads(json.dumps(before))
        after["images"][candidate.entry_id] = {
            **after["images"].get(candidate.entry_id, {}),
            "closure": str(candidate.generation.closure), "sha256": candidate.image_sha256,
            "pcr_key_fingerprint": fingerprint, "bootmanager_sha256": manager_hash,
        }
        after["default"] = candidate.entry_id
        validate_manifest(after)
        _write_json(state_dir, "journal.json", {
            "version": 1, "old_default": before["default"], "candidate": candidate.entry_id,
            "before": before, "after": after,
        })
        _publish_file(candidate.path, esp / "EFI/Linux" / candidate.entry_id, tools, keys, run, immutable=True)
        manager_backup = esp / "EFI/secure-uki" / f"systemd-boot-{manager_hash}.efi"
        _publish_file(manager, manager_backup, tools, keys, run, immutable=True)
        for destination in (esp / "EFI/systemd/systemd-bootx64.efi", esp / "EFI/BOOT/BOOTX64.EFI"):
            if before["default"] is not None:
                _verify_pe(destination, tools, keys, run)
                previous = esp / "EFI/secure-uki" / f"systemd-boot-{_image_hash(destination)}.efi"
                _publish_file(destination, previous, tools, keys, run, immutable=True)
            _publish_file(manager, destination, tools, keys, run)
        _pin(after, state_dir, tools, run)
        _select(candidate.entry_id, esp, tools, run)
        # Keep the superset until the committed selection and journal deletion
        # are durable. A failed state write must never trigger pruning.
        write_manifest(state_dir, after)
        (state_dir / "journal.json").unlink()
        _flush_directory(state_dir)
        _prune(after, esp, state_dir)
        write_manifest(state_dir, after)
        return after


def confirm_boot(booted_closure, esp, state_dir, run) -> dict:
    """Confirm actual loaded identity, never the activated/current-system link.

    CLI supplies the resolved /run/booted-system path and a fixed-tool runner.
    Confirmation does not select a default or prune; both share install's lock.
    """
    if not CLOSURE.fullmatch(str(booted_closure)):
        raise ValueError("invalid booted closure")
    with installer_lock(state_dir):
        journal = state_dir / "journal.json"
        if journal.exists() or journal.is_symlink():
            raise ValueError("pending publication cannot be confirmed")
        manifest = load_manifest(state_dir)
        loaded = Path(run(["bootctl", f"--esp-path={esp}", "--print-stub-path"]).strip())
        _entry_digest(loaded.name)
        if loaded != esp / "EFI/Linux" / loaded.name or loaded.is_symlink():
            raise ValueError("loaded UKI is not on the expected ESP")
        record = manifest["images"].get(loaded.name)
        if not record or record["closure"] != str(booted_closure):
            raise ValueError("loaded image and booted closure do not match retained state")
        if _image_hash(loaded) != record["sha256"]:
            raise ValueError("loaded image identity cannot be verified")
        if (run(["systemctl", "is-active", "multi-user.target"]).strip() != "active"
                or run(["systemctl", "is-system-running"]).strip() != "running"):
            raise ValueError("system is not ready for boot confirmation")
        manifest["known_good"] = loaded.name
        write_manifest(state_dir, manifest)
        return manifest


def write_manifest(state_dir: Path, manifest: dict) -> None:
    validate_manifest(manifest)
    _write_json(state_dir, "manifest.json", manifest)
