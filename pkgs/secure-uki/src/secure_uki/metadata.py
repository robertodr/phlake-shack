"""Immutable installer contracts and validated generation metadata."""

from collections.abc import Callable, Sequence
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path

Run = Callable[[Sequence[str]], str]


@dataclass(frozen=True)
class Generation:
    closure: Path
    kernel: Path
    initrd: Path
    init: Path
    os_release: Path
    cmdline: str
    label: str
    generation_id: str


@dataclass(frozen=True)
class PreparedImage:
    generation: Generation
    path: Path
    image_sha256: str
    pcr_key_fingerprint: str
    entry_id: str


@dataclass(frozen=True)
class Tools:
    ukify: Path
    measure: Path
    sbsign: Path
    sbverify: Path
    bootctl: Path
    nix_store: Path


@dataclass(frozen=True)
class Keys:
    db_key: Path
    db_cert: Path
    pcr_private: Path
    pcr_public: Path


def _text(value: object, field: str) -> str:
    if not isinstance(value, str) or not value or any(ord(c) < 32 or ord(c) == 127 for c in value):
        raise ValueError(f"{field} must be nonempty text without control characters")
    return value


def _store_path(value: object, field: str, root: Path, *, directory: bool = False) -> Path:
    text = _text(value, field)
    if not Path(text).is_absolute() or any(c.isspace() for c in text) or '"' in text:
        raise ValueError(f"{field} must be an unambiguous absolute store path")
    try:
        path = Path(text).resolve(strict=True)
        # A harmless-looking alias must not inject tokens via its symlink target.
        resolved_text = _text(str(path), field)
        if any(c.isspace() for c in resolved_text) or '"' in resolved_text:
            raise ValueError(f"{field} resolves to an ambiguous store path")
        if path == root or not path.is_relative_to(root):
            raise ValueError(f"{field} must remain inside the store")
        if not (path.is_dir() if directory else path.is_file()):
            raise ValueError(f"{field} must be a regular {'directory' if directory else 'file'}")
        return path
    except (OSError, RuntimeError) as exc:
        raise ValueError(f"{field} is missing or cannot be resolved inside the store") from exc


def _unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate Bootspec JSON key")
        result[key] = value
    return result


def read_generation(closure: Path, *, store_root: Path = Path("/nix/store")) -> Generation:
    """Read a single x86_64 Bootspec v1 profile; alternate store roots are unit-only.

    Paths are canonicalized before containment and identity checks. No live
    /etc state, private signing keys, command execution or filesystem writes.
    """
    try:
        root = store_root.resolve(strict=True)
        if not root.is_dir():
            raise ValueError("store root must be a directory")
    except (OSError, RuntimeError) as exc:
        raise ValueError("store root cannot be resolved") from exc
    canonical = _store_path(str(closure), "closure", root, directory=True)
    metadata = _store_path(str(canonical / "boot.json"), "boot.json", root)
    try:
        payload = json.loads(metadata.read_text(encoding="utf-8"), object_pairs_hook=_unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError("invalid Bootspec JSON") from exc
    # Pinned NixOS emits these auxiliary objects even for bash-based init.
    # They do not supply UKI components; unknown extensions/versions still fail.
    auxiliary = {"org.nixos.nixos-init.v1", "org.nixos.systemd-boot"}
    allowed = {"org.nixos.bootspec.v1", "org.nixos.specialisation.v1"} | auxiliary
    if not isinstance(payload, dict) or set(payload) - allowed:
        raise ValueError("unsupported Bootspec schema")
    for name in auxiliary:
        if name in payload and not isinstance(payload[name], dict):
            raise ValueError("auxiliary Bootspec extensions must be objects")
    spec = payload.get("org.nixos.bootspec.v1")
    if not isinstance(spec, dict):
        raise ValueError("Bootspec v1 object is required")
    specialisations = payload.get("org.nixos.specialisation.v1", {})
    if not isinstance(specialisations, dict) or specialisations:
        raise ValueError("only one profile without specialisations is supported")
    required = {"toplevel", "system", "kernel", "initrd", "init", "kernelParams", "label"}
    if not required.issubset(spec):
        raise ValueError("required Bootspec fields are missing")
    if spec["system"] != "x86_64-linux":
        raise ValueError("only x86_64-linux generations are supported")
    if _store_path(spec["toplevel"], "toplevel", root, directory=True) != canonical:
        raise ValueError("Bootspec toplevel does not match the requested closure")
    kernel = _store_path(spec["kernel"], "kernel", root)
    initrd = _store_path(spec["initrd"], "initrd", root)
    init = _store_path(spec["init"], "init", root)
    if init != _store_path(str(canonical / "init"), "selected init", root):
        raise ValueError("init does not belong to the selected generation")
    os_release = _store_path(str(canonical / "etc/os-release"), "os-release", root)
    params = spec["kernelParams"]
    if not isinstance(params, list):
        raise ValueError("kernelParams must be a list")
    for param in params:
        argument = _text(param, "kernel parameter")
        # No shell quoting/reinterpretation. Reject unsupported ambiguous tokens.
        if any(c.isspace() for c in argument) or '"' in argument or argument.startswith("init="):
            raise ValueError("kernel parameters must be single tokens without another init=")
    label = _text(spec["label"], "label")
    cmdline = " ".join([f"init={init}", *params])
    identity = {
        "version": 1, "closure": str(canonical), "kernel": str(kernel),
        "initrd": str(initrd), "init": str(init), "os_release": str(os_release),
        "cmdline": cmdline, "label": label,
    }
    generation_id = hashlib.sha256(json.dumps(identity, sort_keys=True,
                                            separators=(",", ":")).encode()).hexdigest()
    return Generation(canonical, kernel, initrd, init, os_release, cmdline, label, generation_id)
