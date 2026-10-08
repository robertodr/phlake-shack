"""Target-local fwupd helper signing; no firmware execution or update."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile

from .metadata import Keys, Tools
from .prepare import OPENSSL, _private_file, _regular
from .publish import _flush_directory, _verify_pe


def sign_helper(source, destination, tools, keys, run):
    """Reconstruct the volatile sibling from the selected source, never a marker.

    This is a separate runtime operation, not a UKI/default/TPM transaction.
    Failure invalidates a cached signed sibling, preventing reuse by fwupd.
    """
    parent = destination.parent
    stat = parent.stat()
    if parent.is_symlink() or not parent.is_dir() or stat.st_uid != os.geteuid() or stat.st_mode & 0o022:
        raise ValueError("unsafe runtime helper directory")
    if destination.name != "fwupdx64.efi.signed":
        raise ValueError("unsupported helper destination")
    unsigned = destination.with_suffix("")
    for path in (unsigned, destination):
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise ValueError("unsafe runtime helper file")
    destination.unlink(missing_ok=True)
    _flush_directory(parent)
    _regular(source)
    _private_file(keys.db_key)
    _regular(keys.db_cert)
    if keys.db_cert.stat().st_uid != os.geteuid() or keys.db_cert.stat().st_mode & 0o022:
        raise ValueError("certificate must be owner-controlled")
    with tempfile.TemporaryDirectory(prefix=".sign-", dir=parent) as directory:
        stage = Path(directory)
        public, private_der, public_der = stage / "public.pem", stage / "private.der", stage / "public.der"
        run([OPENSSL, "pkey", "-passin", "pass:", "-in", str(keys.db_key), "-pubout",
             "-outform", "DER", "-out", str(private_der)])
        run([OPENSSL, "x509", "-in", str(keys.db_cert), "-pubkey", "-noout", "-out", str(public)])
        run([OPENSSL, "pkey", "-pubin", "-in", str(public), "-outform", "DER", "-out", str(public_der)])
        if private_der.read_bytes() != public_der.read_bytes():
            raise ValueError("signing keypair/certificate does not match")
        copied, signed = stage / "source.efi", stage / "signed.efi"
        shutil.copyfile(source, copied)
        run([str(tools.sbsign), "--key", str(keys.db_key), "--cert", str(keys.db_cert),
             "--output", str(signed), str(copied)])
        _verify_pe(signed, tools, keys, run)
        def sections(path):
            info = json.loads(run([str(tools.ukify), "--all", "--json=short", "inspect", str(path)]))
            if not isinstance(info, dict) or not info:
                raise ValueError("missing helper sections")
            return {name: (data["size"], data["sha256"]) for name, data in info.items()}
        if sections(source) != sections(signed):
            raise ValueError("signed helper differs from selected source")
        if hashlib.sha256(copied.read_bytes()).digest() != hashlib.sha256(source.read_bytes()).digest():
            raise ValueError("selected helper changed while signing")
        for path, target in ((copied, unsigned), (signed, destination)):
            path.chmod(0o644)
            with path.open("rb") as file:
                os.fsync(file.fileno())
            os.replace(path, target)
            _flush_directory(parent)


def main(argv=None):
    if os.geteuid() != 0:
        raise SystemExit("secure-uki-fwupd: root is required; no configuration or keys were accessed")
    from .cli import load_config, check_mounts, _runner
    parser = argparse.ArgumentParser(prog="secure-uki-fwupd")
    parser.add_argument("source", type=Path)
    args = parser.parse_args(argv)
    try:
        os.umask(0o077)
        config = load_config()
        run = _runner(config)
        check_mounts(config, run)
        source = args.source.resolve(strict=True)
        if not args.source.is_absolute() or not source.is_relative_to(Path("/nix/store")) or source.name != "fwupdx64.efi":
            raise ValueError("helper must be a selected Nix-pinned x64 source")
        tools = Tools(**{name: Path(config["tools"][name]) for name in Tools.__dataclass_fields__})
        keys = Keys(**{name: Path(value) for name, value in config["keys"].items()})
        sign_helper(source, Path("/run/fwupd-efi/fwupdx64.efi.signed"), tools, keys, run)
    except (OSError, ValueError, RuntimeError, KeyError, TypeError):
        # No key data, raw subprocess output or user-supplied source in diagnostics.
        raise SystemExit("secure-uki-fwupd: helper signing/verification refused") from None
