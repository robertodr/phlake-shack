"""Root-only target-local installer. Configuration is a fixed Nix-owned file."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from .metadata import Keys, Tools, read_generation
from .prepare import prepare_image, _private_file, _regular
from .publish import confirm_boot, installer_lock, _install_locked, _private_directory, _unique_object

CONFIG_PATH = Path("/etc/secure-uki.json")
TOOL_NAMES = {"ukify", "measure", "sbsign", "sbverify", "bootctl", "nix_store", "systemctl", "findmnt", "cryptsetup"}
KEY_PATHS = {"db_key": "/var/lib/sbctl/keys/db/db.key", "db_cert": "/var/lib/sbctl/keys/db/db.pem",
             "pcr_private": "/var/lib/secure-uki/pcr-signing/private.pem",
             "pcr_public": "/var/lib/secure-uki/pcr-signing/public.pem"}
NIX_TOOL = re.compile(r"/nix/store/[0123456789abcdfghijklmnpqrsvwxyz]{32}-[A-Za-z0-9+._?=-]+/(?:[A-Za-z0-9+._=-]+/)*[A-Za-z0-9+._=-]+")


def validate_config(config):
    fields = {"version", "esp", "state_dir", "encrypted_device", "state_filesystem", "tools", "keys"}
    if (not isinstance(config, dict) or set(config) != fields
            or type(config.get("version")) is not int or config["version"] != 1):
        raise ValueError("unsupported runtime configuration")
    if (config["esp"] != "/boot" or config["state_dir"] != "/var/lib/secure-uki"
            or config["encrypted_device"] != "/dev/mapper/encrypted"
            or config["state_filesystem"] not in {"btrfs", "ext4"}):
        raise ValueError("unsupported target-local paths/filesystem")
    if config["keys"] != KEY_PATHS:
        raise ValueError("signing keys must use fixed target-local string paths, never store paths")
    tools = config["tools"]
    if not isinstance(tools, dict) or set(tools) != TOOL_NAMES:
        raise ValueError("missing fixed tools")
    for value in tools.values():
        if (not isinstance(value, str) or not NIX_TOOL.fullmatch(value)
                or any(part in {".", ".."} for part in Path(value).parts)):
            raise ValueError("tools must use unambiguous Nix-pinned executable paths")
    return config


def load_config():
    # No --config or environment-selected user file. NixOS provides this link.
    path = CONFIG_PATH.resolve(strict=True)
    stat = path.stat()
    if (not path.is_relative_to(Path("/nix/store")) or not path.is_file()
            or stat.st_uid != 0 or stat.st_mode & 0o022):
        raise ValueError("runtime configuration must be a protected Nix-owned file")
    config = validate_config(json.loads(path.read_text(), object_pairs_hook=_unique_object))
    for value in config["tools"].values():
        tool = Path(value).resolve(strict=True)
        stat = tool.stat()
        if (not tool.is_relative_to(Path("/nix/store")) or not tool.is_file()
                or stat.st_uid != 0 or stat.st_mode & 0o022 or not os.access(tool, os.X_OK)):
            raise ValueError("unsafe runtime tool")
    return config


def check_mounts(config, run):
    def mount(path):
        value = json.loads(run([config["tools"]["findmnt"], "--json", "--first-only", "--target", path,
                               "--output", "TARGET,SOURCE,FSTYPE"]))
        rows = value.get("filesystems") if isinstance(value, dict) else None
        if not isinstance(rows, list) or len(rows) != 1 or not isinstance(rows[0], dict):
            raise ValueError("expected mounted target filesystem")
        return rows[0]
    esp = mount(config["esp"])
    if esp.get("target") != config["esp"] or esp.get("fstype") != "vfat":
        raise ValueError("ESP must be the actual mounted vfat filesystem")
    for path, target in ((config["state_dir"], config["state_dir"]),
                         ("/var/lib/sbctl", "/var/lib/sbctl"),
                         ("/var/lib/secure-uki/pcr-signing", config["state_dir"])):
        row = mount(path)
        source = row.get("source", "")
        if (row.get("target") != target or row.get("fstype") != config["state_filesystem"]
                or not isinstance(source, str) or source.split("[", 1)[0] != config["encrypted_device"]):
            raise ValueError("state and keys require mounted encrypted persistence before signing")
    status = run([config["tools"]["cryptsetup"], "status", config["encrypted_device"]])
    if not re.search(r"^\s*type:\s*LUKS2\s*$", status, re.MULTILINE):
        raise ValueError("persistent backing mapper must be active LUKS2")


def check_augmentations(esp):
    for directory in (esp / "loader/addons", esp / "loader/credentials",
                      *(esp / "EFI/Linux").glob("*.extra.d")):
        if directory.is_symlink() or (directory.exists() and
                                      (not directory.is_dir() or any(directory.iterdir()))):
            raise ValueError("external addons, credentials and extensions are unsupported")


def check_initrd_secrets(closure):
    value = json.loads((closure / "boot.json").read_text(), object_pairs_hook=_unique_object)
    spec = value["org.nixos.bootspec.v1"]
    if any(spec.get(name) is not None for name in ("initrdSecrets", "initrdSecretsAppend")):
        raise ValueError("initrd secret append handling is unsupported; refusing to omit it")


def cleanup_staging(state):
    """Caller holds installer_lock; no other CLI can be preparing in this state."""
    _private_directory(state)
    for path in state.iterdir():
        if path.name.startswith((".prepare-call-", ".install-")):
            _private_directory(path)
            shutil.rmtree(path)


def _runner(config):
    def run(argv):
        argv = list(argv)
        if argv[0] in config["tools"]:
            argv[0] = config["tools"][argv[0]]
        # prepare uses the package's immutable OpenSSL PATH; every other tool
        # is explicit. No shell, interactive passphrase or command interpolation.
        try:
            return subprocess.run(argv, check=True, capture_output=True, text=True).stdout
        except subprocess.CalledProcessError as exc:
            # Do not echo raw tool output, key material or untrusted Bootspec text.
            raise RuntimeError(f"{Path(argv[0]).name} failed (exit {exc.returncode})") from exc
    return run


def main(argv=None):
    if os.geteuid() != 0:
        raise SystemExit("secure-uki: root is required; no configuration or keys were accessed")
    parser = argparse.ArgumentParser(prog="secure-uki")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("install").add_argument("closure", type=Path)
    commands.add_parser("confirm-boot")
    args = parser.parse_args(argv)
    try:
        os.umask(0o077)
        config = load_config()
        run = _runner(config)
        check_mounts(config, run)
        esp, state = Path(config["esp"]), Path(config["state_dir"])
        _private_directory(state)
        _private_directory(Path("/var/lib/sbctl"))
        check_augmentations(esp)
        keys = Keys(**{name: Path(value) for name, value in config["keys"].items()})
        for key in (keys.db_key, keys.pcr_private):
            _private_file(key)
        for public in (keys.db_cert, keys.pcr_public):
            _regular(public)
            if public.stat().st_uid != 0 or public.stat().st_mode & 0o022:
                raise ValueError("public signing material must be root-controlled")
        if args.command == "confirm-boot":
            booted = Path("/run/booted-system").resolve(strict=True)
            confirm_boot(booted, esp, state, run)
        else:
            generation = read_generation(args.closure)
            check_initrd_secrets(generation.closure)
            tools = Tools(**{name: Path(config["tools"][name]) for name in Tools.__dataclass_fields__})
            # Serialize preparation, staging cleanup and publication as one
            # operation. Kernel lock release after SIGKILL allows safe replay.
            with installer_lock(state):
                cleanup_staging(state)
                with tempfile.TemporaryDirectory(prefix=".prepare-call-", dir=state) as directory:
                    candidate = prepare_image(generation, Path(directory), tools, keys, run)
                    _install_locked(candidate, esp, state, tools, keys, run)
        print("secure-uki: operation completed")
    except (OSError, ValueError, RuntimeError, KeyError, TypeError) as exc:
        # No plaintext key/passphrase data in diagnostics. Fixed, bounded messages.
        if isinstance(exc, (KeyError, TypeError)):
            message = "malformed runtime metadata"
        elif isinstance(exc, OSError):
            message = "required file, mount or durable filesystem operation failed"
        else:
            message = str(exc)
        raise SystemExit(f"secure-uki: {message}") from None


if __name__ == "__main__":
    main()
