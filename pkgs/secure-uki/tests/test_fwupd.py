import hashlib
import json
from pathlib import Path
import unittest
from unittest.mock import patch

import test_prepare as fixtures
from secure_uki.fwupd import sign_helper


class HelperRunner(fixtures.ImageTools):
    mismatch = False

    def __call__(self, argv):
        if Path(argv[0]).name == "ukify" and "inspect" in argv:
            self.calls.append(list(argv))
            digest = hashlib.sha256(b"fixture helper section").hexdigest()
            if self.mismatch and Path(argv[-1]).name == "signed.efi":
                digest = "f" * 64
            return json.dumps({".text": {"size": 22, "sha256": digest}})
        return super().__call__(argv)


class HelperTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.PrepareTests.setUpClass.__func__(cls)

    @classmethod
    def tearDownClass(cls):
        fixtures.PrepareTests.tearDownClass.__func__(cls)

    def setUp(self):
        fixtures.PrepareTests.setUp(self)
        self.run = HelperRunner()
        self.source = self.root / "selected-helper.efi"
        self.source.write_bytes(b"selected helper")
        self.runtime = self.root / "runtime"
        self.runtime.mkdir(mode=0o700)
        self.target = self.runtime / "fwupdx64.efi.signed"
        self.target.write_bytes(b"stale unsigned marker")

    def sign(self):
        sign_helper(self.source, self.target, self.tools, self.keys, self.run)

    def test_signs_current_source_not_stale_marker(self):
        self.sign()
        self.assertNotEqual(self.target.read_bytes(), b"stale unsigned marker")
        self.assertTrue(self.target.read_bytes().endswith(self.source.read_bytes()))
        self.assertEqual((self.runtime / "fwupdx64.efi").read_bytes(), self.source.read_bytes())
        self.assertFalse(any(p.name.startswith(".sign-") for p in self.runtime.iterdir()))

    def test_changed_source_rebuilds_signed_sibling(self):
        self.sign()
        self.source.write_bytes(b"updated helper")
        self.sign()
        self.assertTrue(self.target.read_bytes().endswith(b"updated helper"))

    def test_failed_signature_or_source_match_leaves_no_signed_marker(self):
        for mode in ("sbverify", "sbsign", "mismatch"):
            with self.subTest(mode=mode):
                self.target.write_bytes(b"stale marker")
                self.run = HelperRunner()
                if mode == "mismatch":
                    self.run.mismatch = True
                else:
                    self.run.fail_tool = mode
                with self.assertRaises((ValueError, RuntimeError)):
                    self.sign()
                self.assertFalse(self.target.exists())
                self.assertFalse(any(p.name.startswith(".sign-") for p in self.runtime.iterdir()))

    def test_missing_or_exposed_key_refused_without_cached_signed_file(self):
        self.keys.db_key.chmod(0o644)
        with self.assertRaises(ValueError):
            self.sign()
        self.assertFalse(self.target.exists())
        self.keys.db_key.unlink()
        with self.assertRaises(ValueError):
            self.sign()

    def test_root_guard_precedes_configuration_loading(self):
        from secure_uki.fwupd import main
        with patch("secure_uki.fwupd.os.geteuid", return_value=1000), \
             patch("secure_uki.cli.load_config", side_effect=AssertionError("configuration read too early")):
            with self.assertRaises(SystemExit) as result:
                main(["/nonexistent-helper"])
            self.assertIn("root", str(result.exception))

    def test_unsafe_runtime_symlink_refused(self):
        other = self.root / "owner-data"
        other.write_bytes(b"preserve")
        self.target.unlink()
        self.target.symlink_to(other)
        with self.assertRaises(ValueError):
            self.sign()
        self.assertEqual(other.read_bytes(), b"preserve")
