"""Mock only PE/measurement tools; key and policy-signature checks use OpenSSL."""

import base64
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dataclasses import replace

from secure_uki.metadata import Generation, Keys, PreparedImage, Tools
from secure_uki.prepare import prepare_image


def command(argv):
    return subprocess.run(argv, check=True, capture_output=True, text=True).stdout


class ImageTools:
    def __init__(self):
        self.calls = []
        self.sections = {}
        self.corrupt_section = None
        self.bad_signature = False
        self.bad_policy = False
        self.extra_bank = False
        self.fail_tool = None
        self.omit_signed_output = False
        self.policy = hashlib.sha256(b"fixture-initrd-policy").hexdigest()

    def __call__(self, argv):
        self.calls.append(list(argv))
        name = Path(argv[0]).name
        if name == self.fail_tool:
            raise RuntimeError("injected tool failure")
        if name == "openssl":
            return command(argv)
        args = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in argv[1:] if "=" in a}
        if name == "ukify" and "build" in argv:
            for section, option in ((".linux", "--linux"), (".initrd", "--initrd"),
                                    (".osrel", "--os-release"), (".cmdline", "--cmdline"),
                                    (".pcrpkey", "--pcr-public-key")):
                self.sections[section] = Path(args[option].lstrip("@")).read_bytes()
            self.sections[".uname"] = b"fixture-kernel"
            self.sections[".sbat"] = b"fixture-sbat"
            stage = Path(args["--output"]).parent
            command(["openssl", "rsa", "-pubin", "-in", args["--pcr-public-key"],
                     "-RSAPublicKey_out", "-outform", "DER", "-out", str(stage / "fake-public.der")])
            fingerprint = hashlib.sha256((stage / "fake-public.der").read_bytes()).hexdigest()
            policy = "f" * 64 if self.bad_policy else self.policy
            (stage / "fake-policy").write_bytes(bytes.fromhex(policy))
            command(["openssl", "dgst", "-sha256", "-sign", args["--pcr-private-key"],
                     "-out", str(stage / "fake-signature"), str(stage / "fake-policy")])
            sig = b"broken-signature" if self.bad_signature else (stage / "fake-signature").read_bytes()
            data = {"sha256": [{"pcrs": [11], "pkfp": fingerprint, "pol": policy,
                                 "sig": base64.b64encode(sig).decode()}]}
            if self.extra_bank:
                data["sha1"] = data["sha256"]
            self.sections[".pcrsig"] = json.dumps(data).encode()
            if self.corrupt_section:
                self.sections[self.corrupt_section] = b"wrong component"
            Path(args["--output"]).write_bytes(b"unsigned" + b"".join(self.sections.values()))
            return ""
        if name == "sbsign":
            if not self.omit_signed_output:
                out = Path(argv[argv.index("--output") + 1])
                cert = Path(argv[argv.index("--cert") + 1])
                out.write_bytes(b"signed" + cert.read_bytes() + Path(argv[-1]).read_bytes())
            return ""
        if name == "sbverify":
            return "Signature verification OK"
        if name == "ukify" and "inspect" in argv:
            for value in argv:
                if value.startswith("--section="):
                    section, destination = value.removeprefix("--section=").split(":binary@", 1)
                    Path(destination).write_bytes(self.sections[section])
            return json.dumps({k: {"size": len(v), "sha256": hashlib.sha256(v).hexdigest()}
                               for k, v in self.sections.items()})
        if name == "measure" and "policy-digest" in argv:
            return json.dumps({"sha256": [{"pcrs": [11], "pol": self.policy}]})
        raise AssertionError(f"unexpected tool: {name}")


class PrepareTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.key_tmp = tempfile.TemporaryDirectory()
        root = Path(cls.key_tmp.name)
        command(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                 "-subj", "/CN=disposable-unit-db", "-keyout", str(root / "db.key"),
                 "-out", str(root / "db.pem")])
        command(["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048",
                 "-out", str(root / "pcr.key")])
        command(["openssl", "pkey", "-in", str(root / "pcr.key"), "-pubout", "-out", str(root / "pcr.pem")])

    @classmethod
    def tearDownClass(cls):
        cls.key_tmp.cleanup()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for path in Path(self.key_tmp.name).iterdir():
            shutil.copy2(path, self.root / path.name)
        for name in ("db.key", "pcr.key"):
            (self.root / name).chmod(0o600)
        self.keys = Keys(self.root / "db.key", self.root / "db.pem",
                         self.root / "pcr.key", self.root / "pcr.pem")
        self.tools = Tools(*(Path("/tools") / x for x in
                             ("ukify", "measure", "sbsign", "sbverify", "bootctl", "nix-store")))
        for name, data in (("kernel", b"kernel"), ("initrd", b"microcode-prefix\x00compressed-initrd"),
                           ("init", b"init"), ("os-release", b"ID=nixos\n")):
            (self.root / name).write_bytes(data)
        self.generation = Generation(self.root, self.root / "kernel", self.root / "initrd",
                                     self.root / "init", self.root / "os-release",
                                     f"init={self.root}/init quiet", "fixture", "a" * 64)
        self.destination = self.root / "prepared"
        self.destination.mkdir(mode=0o700)
        self.boot_default = self.root / "loader.conf"
        self.boot_default.write_text("default known-good.efi\n")
        self.run = ImageTools()

    def prepare(self, **kwargs):
        return prepare_image(kwargs.get("generation", self.generation), self.destination,
                             self.tools, kwargs.get("keys", self.keys), self.run)

    def assert_no_boot_side_effects(self):
        self.assertEqual(self.boot_default.read_text(), "default known-good.efi\n")
        names = {Path(call[0]).name for call in self.run.calls}
        self.assertFalse(names & {"bootctl", "nix-store", "systemd-cryptenroll", "sbctl"})

    def test_final_bytes_identity_and_private_staging(self):
        image = self.prepare()
        self.assertIsInstance(image, PreparedImage)
        digest = hashlib.sha256(image.path.read_bytes()).hexdigest()
        self.assertEqual(image.image_sha256, digest)
        self.assertEqual(image.entry_id, f"dancer-{digest}.efi")
        self.assertEqual(image.path.name, image.entry_id)
        self.assertEqual(image.generation, self.generation)
        self.assertEqual(image.path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(image.path.parent.stat().st_mode & 0o777, 0o700)
        self.assertEqual(list(image.path.parent.iterdir()), [image.path])
        self.assert_no_boot_side_effects()

    def test_fingerprint_matches_systemd_rsa_der_encoding(self):
        der = self.root / "systemd-public.der"
        command(["openssl", "rsa", "-pubin", "-in", str(self.keys.pcr_public),
                 "-RSAPublicKey_out", "-outform", "DER", "-out", str(der)])
        image = self.prepare()
        self.assertIsInstance(image, PreparedImage)
        self.assertEqual(image.pcr_key_fingerprint, hashlib.sha256(der.read_bytes()).hexdigest())

    def test_exact_selected_components_and_initrd_only_policy(self):
        image = self.prepare()
        self.assertIsInstance(image, PreparedImage)
        build = next(c for c in self.run.calls if "build" in c)
        self.assertIn("--pcr-banks=sha256", build)
        self.assertIn("--phases=enter-initrd", build)
        self.assertEqual(self.run.sections[".cmdline"], self.generation.cmdline.encode())
        self.assertEqual(self.run.sections[".linux"], b"kernel")
        self.assertEqual(self.run.sections[".initrd"], b"microcode-prefix\x00compressed-initrd")
        self.assertEqual(self.run.sections[".osrel"], b"ID=nixos\n")
        self.assertEqual(self.run.sections[".pcrpkey"], self.keys.pcr_public.read_bytes())
        verify = [c for c in self.run.calls if c[0] == "openssl" and "-verify" in c]
        self.assertEqual(len(verify), 1)
        self.assert_no_boot_side_effects()

    def test_wrong_policy_signature_is_cryptographically_rejected(self):
        self.run.bad_signature = True
        with self.assertRaises((ValueError, subprocess.CalledProcessError)):
            self.prepare()
        self.assertEqual(list(self.destination.iterdir()), [])
        self.assert_no_boot_side_effects()

    def test_wrong_signed_policy_is_rejected(self):
        self.run.bad_policy = True
        with self.assertRaises(ValueError):
            self.prepare()
        self.assert_no_boot_side_effects()

    def test_other_pcr_bank_is_rejected(self):
        self.run.extra_bank = True
        with self.assertRaises(ValueError):
            self.prepare()

    def test_altered_component_is_rejected(self):
        for section in (".linux", ".initrd", ".cmdline", ".osrel", ".pcrpkey"):
            with self.subTest(section=section):
                self.run = ImageTools()
                self.run.corrupt_section = section
                with self.assertRaises(ValueError):
                    self.prepare()
                self.assertEqual(list(self.destination.iterdir()), [])

    def test_missing_key_is_rejected_before_build(self):
        self.keys.pcr_private.unlink()
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertFalse(any("build" in c for c in self.run.calls))

    def test_world_readable_private_key_is_rejected(self):
        self.keys.db_key.chmod(0o644)
        with self.assertRaises(ValueError):
            self.prepare()

    def test_mismatched_pcr_keypair_is_rejected(self):
        command(["openssl", "pkey", "-in", str(self.keys.db_key), "-pubout", "-out", str(self.keys.pcr_public)])
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertFalse(any("build" in c for c in self.run.calls))

    def test_mismatched_db_certificate_is_rejected(self):
        command(["openssl", "req", "-x509", "-key", str(self.keys.pcr_private), "-days", "1",
                 "-subj", "/CN=other-unit-db", "-out", str(self.keys.db_cert)])
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertFalse(any("build" in c for c in self.run.calls))

    def test_tool_failures_preserve_previous_default_and_cleanup(self):
        for tool in ("ukify", "sbsign", "sbverify", "measure"):
            with self.subTest(tool=tool):
                self.run = ImageTools()
                self.run.fail_tool = tool
                with self.assertRaises(RuntimeError):
                    self.prepare()
                self.assertEqual(list(self.destination.iterdir()), [])
                self.assert_no_boot_side_effects()

    def test_zero_signer_exit_without_output_is_rejected(self):
        self.run.omit_signed_output = True
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_declared_split_microcode_is_rejected(self):
        (self.root / "boot.json").write_text(json.dumps({
            "org.nixos.bootspec.v1": {"ucode": "/unproven-split-microcode"},
        }))
        with self.assertRaisesRegex(ValueError, "split-microcode"):
            self.prepare()
        self.assertEqual(self.run.calls, [])
        self.assert_no_boot_side_effects()

    def test_invalid_cmdline_is_rejected(self):
        for cmdline in ("", "quiet", "init=/other quiet", self.generation.cmdline + "\n",
                        self.generation.cmdline + " init=/other"):
            with self.subTest(cmdline=cmdline):
                with self.assertRaises(ValueError):
                    self.prepare(generation=replace(self.generation, cmdline=cmdline))

    def test_repeated_preparation_does_not_overwrite_previous_image(self):
        first = self.prepare()
        self.assertIsInstance(first, PreparedImage)
        original = first.path.read_bytes()
        second = self.prepare()
        self.assertIsInstance(second, PreparedImage)
        self.assertNotEqual(first.path, second.path)
        self.assertEqual(first.path.read_bytes(), original)
        self.assertEqual(first.entry_id, second.entry_id)
        self.assert_no_boot_side_effects()


if __name__ == "__main__":
    unittest.main()
