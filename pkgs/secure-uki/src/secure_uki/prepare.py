"""Local image preparation only: never publish, select a boot default or enroll."""

import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import tempfile

from .metadata import Generation, Keys, PreparedImage, Run, Tools

# OpenSSL is supplied by the package's fixed PATH, not a user-selected key tool.
OPENSSL = "openssl"
SECTIONS = {".linux": "linux", ".initrd": "initrd", ".osrel": "osrel",
            ".cmdline": "cmdline", ".pcrpkey": "pcrpkey", ".uname": "uname",
            ".sbat": "sbat", ".pcrsig": "pcrsig"}


def _regular(path: Path) -> None:
    if not path.is_file() or path.is_symlink():
        raise ValueError("expected a regular staging/key file")


def _private_file(path: Path) -> None:
    _regular(path)
    stat = path.stat()
    if stat.st_uid != os.geteuid() or stat.st_mode & 0o077:
        raise ValueError("private key must be owner-only")
    if path.resolve().is_relative_to(Path("/nix/store")):
        raise ValueError("private keys must not reside in the Nix store")
    parent = path.parent.stat()
    if parent.st_uid != os.geteuid() or parent.st_mode & 0o022:
        raise ValueError("private key directory must not be writable by other users")


def _key_consistency(keys: Keys, stage: Path, run: Run) -> str:
    for path in (keys.db_key, keys.pcr_private):
        _private_file(path)
    for path in (keys.db_cert, keys.pcr_public):
        _regular(path)
    for name, source in (("db-private.der", keys.db_key), ("pcr-private.der", keys.pcr_private)):
        run([OPENSSL, "pkey", "-passin", "pass:", "-in", str(source), "-pubout",
             "-outform", "DER", "-out", str(stage / name)])
    cert_public = stage / "db-public.pem"
    run([OPENSSL, "x509", "-in", str(keys.db_cert), "-pubkey", "-noout", "-out", str(cert_public)])
    for name, source in (("db-public.der", cert_public), ("pcr-public.der", keys.pcr_public)):
        run([OPENSSL, "pkey", "-pubin", "-in", str(source), "-outform", "DER", "-out", str(stage / name)])
    for prefix in ("db", "pcr"):
        if (stage / f"{prefix}-private.der").read_bytes() != (stage / f"{prefix}-public.der").read_bytes():
            raise ValueError("signing keypair/certificate does not match")
    # v260 pubkey_fingerprint uses i2d_PublicKey: raw RSA PKCS#1 DER, not SPKI.
    raw_der = stage / "pcr-rsa.der"
    run([OPENSSL, "rsa", "-pubin", "-in", str(keys.pcr_public), "-RSAPublicKey_out",
         "-outform", "DER", "-out", str(raw_der)])
    info = run([OPENSSL, "pkey", "-pubin", "-in", str(keys.pcr_public), "-text", "-noout"])
    bits = re.search(r"Public-Key: \((\d+) bit\)", info)
    if not bits or int(bits[1]) < 2048:
        raise ValueError("PCR policy key must be RSA with at least 2048 bits")
    return hashlib.sha256(raw_der.read_bytes()).hexdigest()


def _verified_sections(image: Path, generation: Generation, keys: Keys,
                       stage: Path, tools: Tools, fingerprint: str, run: Run) -> None:
    metadata = json.loads(run([str(tools.ukify), "--json=short", "inspect", str(image)]))
    if not isinstance(metadata, dict) or set(metadata) != set(SECTIONS):
        raise ValueError("unsupported/missing UKI sections or split microcode/profile")
    for description in metadata.values():
        if not isinstance(description, dict):
            raise ValueError("duplicate or malformed UKI section")
    paths = {name: stage / filename for name, filename in SECTIONS.items()}
    for path in paths.values():
        path.touch(mode=0o600)
    run([str(tools.ukify), "--json=short",
         *[f"--section={name}:binary@{path}" for name, path in paths.items()], "inspect", str(image)])
    for name, path in paths.items():
        _regular(path)
        data = path.read_bytes()
        if len(data) != metadata[name]["size"] or hashlib.sha256(data).hexdigest() != metadata[name]["sha256"]:
            raise ValueError("UKI extraction does not match inspected section")
    expected = {".linux": generation.kernel.read_bytes(), ".initrd": generation.initrd.read_bytes(),
                ".osrel": generation.os_release.read_bytes(), ".cmdline": generation.cmdline.encode(),
                ".pcrpkey": keys.pcr_public.read_bytes()}
    for name, data in expected.items():
        if paths[name].read_bytes() != data:
            raise ValueError("UKI component differs from the selected generation/key")
    signatures = json.loads(paths[".pcrsig"].read_bytes().rstrip(b"\0"))
    if not isinstance(signatures, dict) or set(signatures) != {"sha256"}:
        raise ValueError("only SHA256 PCR policy signatures are supported")
    entries = signatures["sha256"]
    if not isinstance(entries, list) or len(entries) != 1 or not isinstance(entries[0], dict):
        raise ValueError("expected exactly one initrd policy signature")
    signature = entries[0]
    if signature.get("pcrs") != [11] or signature.get("pkfp", "").lower() != fingerprint:
        raise ValueError("unexpected PCR signature mask/key fingerprint")
    policy = json.loads(run([str(tools.measure), "policy-digest", "--bank=sha256",
                            "--phase=enter-initrd", f"--public-key={keys.pcr_public}",
                            *[f"--{SECTIONS[name]}={paths[name]}" for name in SECTIONS if name != ".pcrsig"]]))
    predicted = policy["sha256"]
    if len(predicted) != 1 or predicted[0]["pcrs"] != [11]:
        raise ValueError("unexpected calculated policy")
    if signature.get("pol", "").lower() != predicted[0]["pol"].lower():
        raise ValueError("PCR signature does not authorize the actual initrd image phase")
    digest = bytes.fromhex(signature["pol"])
    if len(digest) != 32:
        raise ValueError("invalid SHA256 policy digest")
    policy_file, signature_file = stage / "policy.bin", stage / "signature.bin"
    policy_file.write_bytes(digest)
    signature_file.write_bytes(base64.b64decode(signature["sig"], validate=True))
    run([OPENSSL, "dgst", "-sha256", "-verify", str(keys.pcr_public),
         "-signature", str(signature_file), str(policy_file)])


def prepare_image(generation: Generation, destination: Path, tools: Tools,
                  keys: Keys, run: Run) -> PreparedImage:
    """Produce one verified, privately staged UKI. The caller owns publication.

    Run must execute argument arrays without a shell and raise on nonzero exit.
    The ukify wrapper supplies the pinned stub; no live enrollment signature is
    generated. Errors clean only this invocation's new staging directory.
    """
    tokens = generation.cmdline.split()
    if (not tokens or tokens[0] != f"init={generation.init}"
            or sum(t.startswith("init=") for t in tokens) != 1
            or any(ord(c) < 32 or ord(c) == 127 or c == '"' for c in generation.cmdline)):
        raise ValueError("invalid or ambiguous generation cmdline")
    boot_json = generation.closure / "boot.json"
    if boot_json.is_file():
        spec = json.loads(boot_json.read_text())["org.nixos.bootspec.v1"]
        if any(field in spec for field in ("ucode", "microcode", "microcodeInitrd")):
            raise ValueError("unrecognized split-microcode arrangement")
    destination.mkdir(mode=0o700, parents=True, exist_ok=True)
    dest_stat = destination.stat()
    if destination.is_symlink() or dest_stat.st_uid != os.geteuid() or dest_stat.st_mode & 0o022:
        raise ValueError("preparation destination must be owner-controlled")
    stage = Path(tempfile.mkdtemp(prefix=".prepare-", dir=destination))
    try:
        fingerprint = _key_consistency(keys, stage, run)
        cmdline, unsigned, signed = stage / "input-cmdline", stage / "unsigned.efi", stage / "signed.efi"
        for path in (cmdline, unsigned, signed):
            path.touch(mode=0o600)
        cmdline.write_text(generation.cmdline)
        run([str(tools.ukify), "build", f"--linux={generation.kernel}", f"--initrd={generation.initrd}",
             f"--os-release=@{generation.os_release}", f"--cmdline=@{cmdline}",
             f"--pcr-private-key={keys.pcr_private}", f"--pcr-public-key={keys.pcr_public}",
             "--pcr-banks=sha256", "--phases=enter-initrd", f"--output={unsigned}"])
        run([str(tools.sbsign), "--key", str(keys.db_key), "--cert", str(keys.db_cert),
             "--output", str(signed), str(unsigned)])
        _regular(signed)
        if not signed.stat().st_size:
            raise ValueError("signer produced no image")
        run([str(tools.sbverify), "--cert", str(keys.db_cert), str(signed)])
        _verified_sections(signed, generation, keys, stage, tools, fingerprint, run)
        digest = hashlib.sha256(signed.read_bytes()).hexdigest()
        entry_id = f"dancer-{digest}.efi"
        final = stage / entry_id
        signed.rename(final)
        final.chmod(0o600)
        for path in stage.iterdir():
            if path != final:
                path.unlink()
        return PreparedImage(generation, final, digest, fingerprint, entry_id)
    except BaseException:
        shutil.rmtree(stage)
        raise
