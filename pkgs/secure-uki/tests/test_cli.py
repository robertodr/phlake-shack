"""Guarded CLI and mount checks; no physical activation or host key access."""

import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from secure_uki import cli


def runtime_config():
    systemd = "/nix/store/" + "a" * 32 + "-systemd"
    return {"version": 1, "esp": "/boot", "state_dir": "/var/lib/secure-uki",
            "encrypted_device": "/dev/mapper/encrypted", "state_filesystem": "btrfs",
            "tools": {name: systemd + "/bin/" + name for name in
                      ("ukify", "measure", "sbsign", "sbverify", "bootctl", "nix_store",
                       "systemctl", "findmnt", "cryptsetup")},
            "keys": {"db_key": "/var/lib/sbctl/keys/db/db.key", "db_cert": "/var/lib/sbctl/keys/db/db.pem",
                     "pcr_private": "/var/lib/secure-uki/pcr-signing/private.pem",
                     "pcr_public": "/var/lib/secure-uki/pcr-signing/public.pem"}}


class GuardedCLITests(unittest.TestCase):
    def test_unprivileged_installed_command_refuses_before_key_or_configuration_access(self):
        result = subprocess.run([sys.executable, "-m", "secure_uki.cli", "install", "/nonexistent-system"],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("root", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_root_guard_precedes_configuration_loading(self):
        with patch("secure_uki.cli.os.geteuid", return_value=1000), \
             patch("secure_uki.cli.load_config", side_effect=AssertionError("configuration read too early")):
            with self.assertRaises(SystemExit) as result:
                cli.main(["install", "/nonexistent-system"])
            self.assertIn("root", str(result.exception))

    def test_missing_or_untrusted_root_config_fails_closed_without_traceback(self):
        with patch("secure_uki.cli.os.geteuid", return_value=0), \
             patch("secure_uki.cli.load_config", side_effect=ValueError("untrusted runtime configuration")):
            with self.assertRaises(SystemExit) as result:
                cli.main(["install", "/nonexistent-system"])
            self.assertIn("configuration", str(result.exception))

    def test_only_nix_pinned_tools_and_target_local_string_key_paths_are_accepted(self):
        cfg = runtime_config()
        self.assertEqual(cli.validate_config(cfg), cfg)
        for field, key, value in (("tools", "bootctl", "/usr/bin/bootctl"),
                                  ("tools", "ukify", "/nix/store/../tmp/ukify"),
                                  ("keys", "db_key", "/nix/store/private.pem"),
                                  ("keys", "pcr_private", "relative")):
            with self.subTest(field=field, key=key):
                bad = copy.deepcopy(cfg)
                bad[field][key] = value
                with self.assertRaises(ValueError):
                    cli.validate_config(bad)
        for change in ({"version": 2}, {"version": True}, {"esp": "/tmp/esp"},
                       {"state_dir": "/nix/store/state"}, {"enroll": True}):
            with self.assertRaises(ValueError):
                cli.validate_config({**cfg, **change})

    def mount_runner(self, *, esp_type="vfat", state_source="/dev/mapper/encrypted",
                     state_target="/var/lib/secure-uki", crypt_type="LUKS2"):
        cfg = runtime_config()
        def run(argv):
            if argv[0] == cfg["tools"]["cryptsetup"]:
                return f"/dev/mapper/encrypted is active.\n  type: {crypt_type}\n"
            self.assertEqual(argv[0], cfg["tools"]["findmnt"])
            path = argv[argv.index("--target") + 1]
            if path == "/boot":
                row = {"target": "/boot", "source": "/dev/vda1", "fstype": esp_type}
            elif path.startswith("/var/lib/sbctl"):
                row = {"target": "/var/lib/sbctl", "source": state_source + "[/persist/sbctl]", "fstype": "btrfs"}
            else:
                row = {"target": state_target, "source": state_source + "[/persist/secure-uki]", "fstype": "btrfs"}
            return json.dumps({"filesystems": [row]})
        return run

    def test_mount_guards_require_real_esp_and_encrypted_persistent_key_state_mounts(self):
        cfg = runtime_config()
        self.assertIsNone(cli.check_mounts(cfg, self.mount_runner()))
        for change in ({"esp_type": "ext4"}, {"state_source": "/dev/vda2"},
                       {"state_target": "/"}, {"crypt_type": "PLAIN"}):
            with self.subTest(change=change):
                with self.assertRaises(ValueError):
                    cli.check_mounts(cfg, self.mount_runner(**change))

    def test_external_addons_credentials_and_extensions_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            esp = Path(tmp)
            for relative in ("loader/addons/extra.addon.efi", "loader/credentials/unexpected.cred",
                             "EFI/Linux/image.efi.extra.d/overlay.raw"):
                file = esp / relative
                file.parent.mkdir(parents=True)
                file.write_bytes(b"not supported")
                with self.assertRaises(ValueError):
                    cli.check_augmentations(esp)
                file.unlink()
            self.assertIsNone(cli.check_augmentations(esp))

    def test_locked_cleanup_reclaims_only_owned_interrupted_staging(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp)
            state.chmod(0o700)
            for name in (".prepare-call-old", ".install-old", "pcr-signing", "owner-directory"):
                folder = state / name
                folder.mkdir(mode=0o700)
                (folder / "keep-or-clean").write_bytes(b"fixture")
            cli.cleanup_staging(state)
            self.assertFalse((state / ".prepare-call-old").exists())
            self.assertFalse((state / ".install-old").exists())
            self.assertTrue((state / "pcr-signing/keep-or-clean").exists())
            self.assertTrue((state / "owner-directory/keep-or-clean").exists())

    def test_initrd_secret_append_is_not_silently_omitted(self):
        with tempfile.TemporaryDirectory() as tmp:
            closure = Path(tmp)
            file = closure / "boot.json"
            for value in ("/nix/store/append-script", ["secret"], True):
                file.write_text(json.dumps({"org.nixos.bootspec.v1": {"initrdSecrets": value}}))
                with self.assertRaises(ValueError):
                    cli.check_initrd_secrets(closure)
            file.write_text(json.dumps({"org.nixos.bootspec.v1": {"initrdSecrets": None}}))
            self.assertIsNone(cli.check_initrd_secrets(closure))


if __name__ == "__main__":
    unittest.main()
