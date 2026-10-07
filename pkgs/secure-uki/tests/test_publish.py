"""Real private-state I/O; no ESP, keys or host TPM in manifest tests."""

import copy
from dataclasses import replace
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from secure_uki.publish import confirm_boot, install, installer_lock, load_manifest, validate_manifest, write_manifest
from secure_uki.prepare import prepare_image
import test_prepare as prepare_fixtures


A = "dancer-" + "a" * 64 + ".efi"
B = "dancer-" + "b" * 64 + ".efi"


def fixture_manifest():
    # Literal identities independent of production builders.
    return {"version": 1, "default": B, "known_good": A, "images": {
        A: {"closure": "/nix/store/" + "a" * 32 + "-system-a", "sha256": "a" * 64,
            "pcr_key_fingerprint": "c" * 64},
        B: {"closure": "/nix/store/" + "b" * 32 + "-system-b", "sha256": "b" * 64,
            "pcr_key_fingerprint": "c" * 64}}}


class PublicationRunner:
    """PE tools are external doubles; files, roots and state changes stay real."""
    def __init__(self, backend, events):
        self.backend, self.events = backend, events
        self.default = None
        self.oneshot = None
        self.fail_on = None

    def __call__(self, argv):
        tool = Path(argv[0]).name
        event = None
        if tool == "sbverify":
            event = "verify"
        elif tool == "nix-store":
            event = "pin-closures"
        elif tool == "bootctl" and "set-default" in argv:
            event = "select-default"
        elif tool == "bootctl" and "set-oneshot" in argv:
            event = "clear-oneshot"
        if event:
            self.events.append(event)
            if event == self.fail_on:
                raise OSError("injected command failure")
        if tool == "nix-store":
            root = Path(argv[argv.index("--add-root") + 1])
            closure = argv[argv.index("--realise") + 1]
            root.unlink(missing_ok=True)
            root.symlink_to(closure)
            return closure
        if tool == "bootctl":
            if "set-default" in argv:
                self.default = argv[-1] or None
            elif "set-oneshot" in argv:
                self.oneshot = argv[-1] or None
            else:
                raise AssertionError(f"unexpected bootctl operation: {argv}")
            return ""
        return self.backend(argv)


class PublicationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        prepare_fixtures.PrepareTests.setUpClass.__func__(cls)

    @classmethod
    def tearDownClass(cls):
        prepare_fixtures.PrepareTests.tearDownClass.__func__(cls)

    def setUp(self):
        prepare_fixtures.PrepareTests.setUp(self)
        self.state = self.root / "state"
        self.state.mkdir(mode=0o700)
        self.esp = self.root / "esp"
        self.images = self.esp / "EFI/Linux"
        self.images.mkdir(parents=True)
        (self.esp / "loader").mkdir()
        (self.state / "gc-roots").mkdir(mode=0o700)
        self.tools = replace(self.tools, bootctl=self.root / "tools/bin/bootctl")
        self.tools.bootctl.parent.mkdir(parents=True)
        self.tools.bootctl.write_text("fixture bootctl")
        manager = self.root / "tools/lib/systemd/boot/efi/systemd-bootx64.efi"
        manager.parent.mkdir(parents=True)
        manager.write_bytes(b"fixture pinned systemd-boot")
        for file in (self.esp / "EFI/systemd/systemd-bootx64.efi", self.esp / "EFI/BOOT/BOOTX64.EFI"):
            file.parent.mkdir(parents=True)
            file.write_bytes(b"fixture previous signed bootmanager")
        self.previous_manager = b"fixture previous signed bootmanager"
        self.previous_manager_hash = hashlib.sha256(self.previous_manager).hexdigest()
        self.manager_backups = self.esp / "EFI/secure-uki"
        self.manager_backups.mkdir()
        (self.manager_backups / f"systemd-boot-{self.previous_manager_hash}.efi").write_bytes(self.previous_manager)
        self.old_ids = []
        records = {}
        for letter, payload in (("a", b"confirmed signed A"), ("b", b"unconfirmed signed B")):
            digest = hashlib.sha256(payload).hexdigest()
            entry = f"dancer-{digest}.efi"
            self.old_ids.append(entry)
            (self.images / entry).write_bytes(payload)
            closure = "/nix/store/" + letter * 32 + f"-system-{letter}"
            records[entry] = {"closure": closure, "sha256": digest, "pcr_key_fingerprint": "c" * 64,
                              "bootmanager_sha256": self.previous_manager_hash}
            (self.state / "gc-roots" / entry).symlink_to(closure)
        self.good, self.old_default = self.old_ids
        write_manifest(self.state, {"version": 1, "default": self.old_default,
                                   "known_good": self.good, "images": records})
        self.conf = self.esp / "loader/loader.conf"
        self.conf.write_text(f"timeout 4\ndefault {self.old_default}\neditor no\n")
        self.events = []
        self.runner = PublicationRunner(self.run, self.events)
        self.runner.default = self.runner.oneshot = self.old_default
        self.candidate = self.prepare_candidate("c")
        self.events.clear()

    def prepare_candidate(self, letter):
        generation = replace(self.generation,
                             closure=Path("/nix/store/" + letter * 32 + f"-system-{letter}"),
                             cmdline=f"init={self.generation.init} fixture={letter}")
        return prepare_image(generation, self.destination, self.tools, self.keys, self.run)

    def install(self, candidate=None):
        return install(candidate or self.candidate, self.esp, self.state,
                       self.tools, self.keys, self.runner)

    def test_publication_retains_candidate_and_last_confirmed_boot_not_old_activation(self):
        manifest = self.install()
        self.assertIsInstance(manifest, dict)
        self.assertEqual(manifest["default"], self.candidate.entry_id)
        self.assertEqual(manifest["known_good"], self.good)
        self.assertEqual(set(manifest["images"]), {self.good, self.candidate.entry_id})
        self.assertEqual(self.runner.default, self.candidate.entry_id)
        self.assertIsNone(self.runner.oneshot)
        self.assertIn(f"default {self.candidate.entry_id}\n", self.conf.read_text())
        self.assertIn("editor no\n", self.conf.read_text())
        self.assertEqual((self.images / self.candidate.entry_id).read_bytes(), self.candidate.path.read_bytes())
        self.assertEqual((self.images / self.good).read_bytes(), b"confirmed signed A")
        self.assertFalse((self.images / self.old_default).exists())
        for entry in (self.good, self.candidate.entry_id):
            self.assertTrue((self.state / "gc-roots" / entry).is_symlink())
        self.assertFalse((self.state / "journal.json").exists())

    def test_repeated_updates_without_boot_never_promote_unconfirmed_candidates(self):
        self.assertIsInstance(self.install(), dict)
        candidate_d = self.prepare_candidate("d")
        manifest = self.install(candidate_d)
        self.assertIsInstance(manifest, dict)
        self.assertEqual(manifest["known_good"], self.good)
        self.assertEqual(set(manifest["images"]), {self.good, candidate_d.entry_id})
        self.assertTrue((self.images / self.good).exists())
        self.assertFalse((self.images / self.candidate.entry_id).exists())

    def test_verification_pinning_journal_and_selection_precede_pruning(self):
        real_replace, real_unlink = os.replace, os.unlink
        def rename(source, destination):
            path = Path(destination)
            if path.name == self.candidate.entry_id:
                self.events.append("publish-image")
            if path.name == "journal.json":
                self.events.append("write-journal")
            return real_replace(source, destination)
        def unlink(path, *args, **kwargs):
            if Path(path).name == self.old_default:
                self.events.append("prune")
            return real_unlink(path, *args, **kwargs)
        with patch("secure_uki.publish.os.replace", side_effect=rename), \
             patch("secure_uki.publish.os.unlink", side_effect=unlink):
            self.assertIsInstance(self.install(), dict)
        for before, after in (("verify", "publish-image"), ("pin-closures", "select-default"),
                              ("write-journal", "select-default"), ("select-default", "prune")):
            self.assertLess(self.events.index(before), self.events.index(after))
        self.assertNotIn("enroll", self.events)

    def test_commands_failing_before_selection_preserve_previous_boot_and_closure(self):
        for event in ("verify", "pin-closures", "clear-oneshot", "select-default"):
            with self.subTest(event=event):
                self.runner.fail_on = event
                with self.assertRaises(OSError):
                    self.install()
                self.assertTrue((self.images / self.good).exists())
                self.assertTrue((self.images / self.old_default).exists())
                self.assertTrue((self.state / "gc-roots" / self.good).is_symlink())
                self.assertEqual(load_manifest(self.state)["known_good"], self.good)
        self.runner.fail_on = None
        self.assertIsInstance(self.install(), dict)
        self.assertEqual(load_manifest(self.state)["known_good"], self.good)

    def test_first_install_copy_failure_can_be_reapplied_without_assuming_old_known_good(self):
        write_manifest(self.state, {"version": 1, "default": None, "known_good": None, "images": {}})
        with patch("secure_uki.publish.shutil.copyfileobj", side_effect=OSError("copy failed")):
            with self.assertRaises(OSError):
                self.install()
        self.assertTrue((self.state / "journal.json").exists())
        self.assertFalse((self.images / self.candidate.entry_id).exists())
        self.assertEqual(load_manifest(self.state)["known_good"], None)
        try:
            manifest = self.install()
        except Exception as error:
            self.fail(f"Safe first-install reapplication failed: {type(error).__name__}")
        self.assertIsInstance(manifest, dict)
        self.assertEqual(manifest["default"], self.candidate.entry_id)
        self.assertIsNone(manifest["known_good"])

    def test_bootstrap_reapplication_does_not_select_before_signed_managers_are_present(self):
        write_manifest(self.state, {"version": 1, "default": None, "known_good": None, "images": {}})
        real_replace = os.replace
        def fail_backup(source, destination):
            if Path(destination).parent.name == "secure-uki":
                raise OSError("manager backup publication failed")
            return real_replace(source, destination)
        with patch("secure_uki.publish.os.replace", side_effect=fail_backup):
            with self.assertRaises(OSError):
                self.install()
        self.assertTrue((self.images / self.candidate.entry_id).exists())
        original_runner = self.runner
        def require_signed_managers(argv):
            if "set-default" in argv:
                for path in ("EFI/systemd/systemd-bootx64.efi", "EFI/BOOT/BOOTX64.EFI"):
                    self.assertTrue((self.esp / path).read_bytes().startswith(b"signed"),
                                    "Recovery selected before signed managers were installed")
            return original_runner(argv)
        self.runner = require_signed_managers
        self.assertIsInstance(self.install(), dict)

    def test_state_failure_after_selection_keeps_recoverable_previous_images(self):
        real_replace = os.replace
        def fail_manifest(source, destination):
            if Path(destination).name == "manifest.json":
                raise OSError("manifest replacement failed")
            return real_replace(source, destination)
        with patch("secure_uki.publish.os.replace", side_effect=fail_manifest):
            with self.assertRaises(OSError):
                self.install()
        self.assertEqual(self.runner.default, self.candidate.entry_id)
        self.assertTrue((self.state / "journal.json").exists())
        for entry in (self.good, self.old_default, self.candidate.entry_id):
            self.assertTrue((self.images / entry).exists())
        self.assertEqual(load_manifest(self.state)["known_good"], self.good)
        manifest = self.install()
        self.assertIsInstance(manifest, dict)
        self.assertEqual(manifest["known_good"], self.good)
        self.assertEqual(set(manifest["images"]), {self.good, self.candidate.entry_id})

    def test_manager_backups_are_bounded_by_retained_images_and_foreign_files_are_preserved(self):
        unrelated = self.manager_backups / "owner-file.efi"
        unrelated.write_bytes(b"do not remove")
        orphan = self.manager_backups / ("systemd-boot-" + "f" * 64 + ".efi")
        orphan.write_bytes(b"obsolete installer backup")
        manifest = self.install()
        self.assertIsInstance(manifest, dict)
        self.assertTrue(all("bootmanager_sha256" in row for row in manifest["images"].values()),
                        "Retained manager identities were not recorded")
        refs = {row["bootmanager_sha256"] for row in manifest["images"].values()}
        managed = {p.name for p in self.manager_backups.glob("systemd-boot-*.efi")}
        self.assertEqual(managed, {f"systemd-boot-{digest}.efi" for digest in refs})
        self.assertLessEqual(len(managed), 2)
        self.assertEqual(unrelated.read_bytes(), b"do not remove")

    def test_tampered_retained_manager_refuses_selection_and_pruning(self):
        backup = self.manager_backups / f"systemd-boot-{self.previous_manager_hash}.efi"
        backup.write_bytes(b"tampered backup")
        with self.assertRaises(ValueError):
            self.install()
        self.assertEqual(self.runner.default, self.old_default)
        self.assertTrue((self.images / self.good).exists())

    def test_interrupted_manager_replacement_restores_verified_previous_copies_before_rollback_selection(self):
        real_replace = os.replace
        def fail_fallback(source, destination):
            if Path(destination).name == "BOOTX64.EFI":
                raise OSError("fallback rename failure")
            return real_replace(source, destination)
        with patch("secure_uki.publish.os.replace", side_effect=fail_fallback):
            with self.assertRaises(OSError):
                self.install()
        original_runner = self.runner
        def require_restored(argv):
            if "set-default" in argv and argv[-1] == self.old_default:
                for path in ("EFI/systemd/systemd-bootx64.efi", "EFI/BOOT/BOOTX64.EFI"):
                    self.assertEqual((self.esp / path).read_bytes(), self.previous_manager,
                                     "Rollback selected before restoring its signed manager")
            return original_runner(argv)
        self.runner = require_restored
        self.assertIsInstance(self.install(), dict)

    def test_incompatible_or_inconsistent_journal_is_not_ignored(self):
        before = load_manifest(self.state)
        after = copy.deepcopy(before)
        after["default"] = self.good
        for corrupt in ({"version": 2}, {"candidate": self.old_default}, {"before": None},
                        {"old_default": "../../bad"}):
            journal = {"version": 1, "old_default": before["default"], "candidate": after["default"],
                       "before": before, "after": after, **corrupt}
            file = self.state / "journal.json"
            file.write_text(json.dumps(journal))
            file.chmod(0o600)
            with self.subTest(corrupt=corrupt):
                with self.assertRaises(ValueError):
                    self.install()
                self.assertTrue(file.exists())
                self.assertEqual(self.runner.default, self.old_default)
                self.assertTrue((self.images / self.good).exists())

    def confirmation_runner(self, *, loaded=None, ready=True):
        def run(argv):
            if argv[0] == "bootctl" and "--print-stub-path" in argv:
                return str(loaded or self.images / self.candidate.entry_id) + "\n"
            if argv == ["systemctl", "is-active", "multi-user.target"]:
                return "active\n" if ready else "inactive\n"
            if argv == ["systemctl", "is-system-running"]:
                return "running\n" if ready else "degraded\n"
            raise AssertionError(f"unexpected confirmation command: {argv}")
        return run

    def test_confirmation_requires_actual_loaded_image_and_booted_closure(self):
        self.assertIsInstance(self.install(), dict)
        result = confirm_boot(self.candidate.generation.closure, self.esp, self.state,
                              self.confirmation_runner())
        self.assertIsInstance(result, dict)
        self.assertEqual(result["known_good"], self.candidate.entry_id)
        self.assertEqual(result["default"], self.candidate.entry_id)
        self.assertEqual(load_manifest(self.state)["known_good"], self.candidate.entry_id)

    def test_activation_closure_cannot_confirm_a_different_loaded_uki(self):
        self.assertIsInstance(self.install(), dict)
        for loaded in (self.images / self.good, self.esp / "other" / self.candidate.entry_id):
            with self.subTest(loaded=loaded):
                with self.assertRaises(ValueError):
                    confirm_boot(self.candidate.generation.closure, self.esp, self.state,
                                 self.confirmation_runner(loaded=loaded))
                self.assertEqual(load_manifest(self.state)["known_good"], self.good)

    def test_not_ready_tampered_or_pending_transaction_cannot_be_confirmed(self):
        self.assertIsInstance(self.install(), dict)
        with self.assertRaises(ValueError):
            confirm_boot(self.candidate.generation.closure, self.esp, self.state,
                         self.confirmation_runner(ready=False))
        (self.images / self.candidate.entry_id).write_bytes(b"tampered")
        with self.assertRaises(ValueError):
            confirm_boot(self.candidate.generation.closure, self.esp, self.state,
                         self.confirmation_runner())
        (self.images / self.candidate.entry_id).write_bytes(self.candidate.path.read_bytes())
        (self.state / "journal.json").write_text("pending")
        with self.assertRaises(ValueError):
            confirm_boot(self.candidate.generation.closure, self.esp, self.state,
                         self.confirmation_runner())
        self.assertEqual(load_manifest(self.state)["known_good"], self.good)

    def test_confirmation_preserves_new_default_when_confirming_retained_boot(self):
        self.assertIsInstance(self.install(), dict)
        closure = Path(load_manifest(self.state)["images"][self.good]["closure"])
        result = confirm_boot(closure, self.esp, self.state,
                              self.confirmation_runner(loaded=self.images / self.good))
        self.assertIsInstance(result, dict)
        self.assertEqual(result["default"], self.candidate.entry_id)
        self.assertEqual(result["known_good"], self.good)

    def test_filesystem_failure_boundaries_leave_confirmed_image_and_can_reapply(self):
        for boundary in ("journal", "image", "primary", "fallback", "loader", "manifest", "prune", "flush"):
            with self.subTest(boundary=boundary):
                self.setUp()
                real_replace, real_unlink, real_fsync = os.replace, os.unlink, os.fsync
                injected = []
                def rename(source, destination):
                    name = Path(destination).name
                    matches = {"journal": "journal.json", "image": self.candidate.entry_id,
                               "primary": "systemd-bootx64.efi", "fallback": "BOOTX64.EFI",
                               "loader": "loader.conf", "manifest": "manifest.json"}
                    if boundary in matches and name == matches[boundary] and not injected:
                        injected.append(True)
                        raise OSError("injected rename")
                    return real_replace(source, destination)
                def unlink(path, *args, **kwargs):
                    if boundary == "prune" and Path(path).name == self.old_default and not injected:
                        injected.append(True)
                        raise OSError("injected prune")
                    return real_unlink(path, *args, **kwargs)
                def flush(fd):
                    if boundary == "flush" and not injected:
                        injected.append(True)
                        raise OSError("injected flush")
                    return real_fsync(fd)
                with patch("secure_uki.publish.os.replace", side_effect=rename), \
                     patch("secure_uki.publish.os.unlink", side_effect=unlink), \
                     patch("secure_uki.publish.os.fsync", side_effect=flush):
                    with self.assertRaises(OSError):
                        self.install()
                self.assertTrue(injected)
                self.assertTrue((self.images / self.good).is_file())
                self.assertTrue((self.state / "gc-roots" / self.good).is_symlink())
                self.assertEqual(load_manifest(self.state)["known_good"], self.good)
                self.assertIsInstance(self.install(), dict)
                self.assertEqual(load_manifest(self.state)["known_good"], self.good)

    def test_replayed_transaction_retires_abandoned_image_and_gc_root(self):
        real_replace = os.replace
        def fail_manifest(source, destination):
            if Path(destination).name == "manifest.json":
                raise OSError("state failure")
            return real_replace(source, destination)
        with patch("secure_uki.publish.os.replace", side_effect=fail_manifest):
            with self.assertRaises(OSError):
                self.install()
        abandoned = self.candidate.entry_id
        candidate_d = self.prepare_candidate("d")
        result = self.install(candidate_d)
        self.assertIsInstance(result, dict)
        self.assertFalse((self.images / abandoned).exists(), "Unindexed failed candidate leaked ESP space")
        self.assertFalse((self.state / "gc-roots" / abandoned).is_symlink())
        self.assertTrue((self.images / self.good).exists())
        self.assertEqual(result["known_good"], self.good)

    def test_reconciliation_does_not_overwrite_an_unknown_current_manifest_version(self):
        before = load_manifest(self.state)
        after = copy.deepcopy(before)
        after["default"] = self.good
        journal = {"version": 1, "old_default": before["default"], "candidate": self.good,
                   "before": before, "after": after}
        file = self.state / "journal.json"
        file.write_text(json.dumps(journal))
        file.chmod(0o600)
        manifest_file = self.state / "manifest.json"
        manifest_file.write_text(json.dumps({**before, "version": 9}))
        manifest_file.chmod(0o600)
        original = manifest_file.read_bytes()
        with self.assertRaises(ValueError):
            self.install()
        self.assertEqual(manifest_file.read_bytes(), original)
        self.assertEqual(self.runner.default, self.old_default)
        self.assertTrue(file.exists())

    def test_existing_symlink_does_not_replace_nix_closure_realisation_and_root_registration(self):
        (self.state / "gc-roots" / self.candidate.entry_id).symlink_to(self.candidate.generation.closure)
        self.runner.fail_on = "pin-closures"
        with self.assertRaises(OSError):
            self.install()
        self.assertEqual(self.runner.default, self.old_default)
        self.assertTrue((self.images / self.good).exists())

    def test_reinstall_preserves_compatible_fields_on_the_same_image_record(self):
        result = self.install()
        self.assertIsInstance(result, dict)
        result["images"][self.candidate.entry_id]["compatible_owner_note"] = {"retain": True}
        write_manifest(self.state, result)
        installed = self.install()
        self.assertIsInstance(installed, dict)
        self.assertEqual(installed["images"][self.candidate.entry_id].get("compatible_owner_note"), {"retain": True})

    def test_same_uki_reapplication_recovers_interrupted_manager_update(self):
        self.assertIsInstance(self.install(), dict)
        source = self.root / "tools/lib/systemd/boot/efi/systemd-bootx64.efi"
        source.write_bytes(b"updated pinned manager")
        real_replace = os.replace
        def fail_manifest(source, destination):
            if Path(destination).name == "manifest.json":
                raise OSError("manifest failure after manager update")
            return real_replace(source, destination)
        with patch("secure_uki.publish.os.replace", side_effect=fail_manifest):
            with self.assertRaises(OSError):
                self.install()
        try:
            result = self.install()
        except Exception as error:
            self.fail(f"Same-UKI manager replay failed: {type(error).__name__}")
        self.assertIsInstance(result, dict)
        self.assertEqual(result["known_good"], self.good)
        self.assertEqual(result["default"], self.candidate.entry_id)

    def test_changed_prepared_bytes_cannot_reuse_verified_identity(self):
        self.candidate.path.write_bytes(b"tampered")
        with self.assertRaises(ValueError):
            self.install()
        self.assertEqual(self.runner.default, self.old_default)
        self.assertTrue((self.images / self.old_default).exists())

    def test_insufficient_peak_space_does_not_prune_to_make_room(self):
        with patch("secure_uki.publish.shutil.disk_usage", return_value=type("Space", (), {"free": 0})()):
            with self.assertRaises(OSError):
                self.install()
        self.assertTrue((self.images / self.old_default).exists())
        self.assertTrue((self.images / self.good).exists())
        self.assertEqual(self.runner.default, self.old_default)


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name)
        self.state.chmod(0o700)
        self.path = self.state / "manifest.json"
        self.manifest = fixture_manifest()

    def raw(self, value):
        self.path.write_text(json.dumps(value))
        self.path.chmod(0o600)

    def test_first_install_has_no_assumed_confirmed_boot(self):
        self.assertEqual(load_manifest(self.state),
                         {"version": 1, "default": None, "known_good": None, "images": {}})
        self.assertEqual(list(self.state.iterdir()), [])

    def test_manifest_roundtrip_preserves_compatible_extra_fields(self):
        self.manifest["operator_note"] = {"revision": 2}
        self.manifest["images"][A]["future_compatible_field"] = ["retained"]
        self.assertEqual(validate_manifest(self.manifest), self.manifest)
        write_manifest(self.state, self.manifest)
        self.assertEqual(load_manifest(self.state), self.manifest)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(list(self.state.iterdir()), [self.path])

    def test_invalid_versions_fail_before_any_state_replacement(self):
        self.raw(self.manifest)
        original = self.path.read_bytes()
        for version in (2, True, "1", None):
            with self.subTest(version=version):
                bad = {**self.manifest, "version": version}
                with self.assertRaises(ValueError):
                    write_manifest(self.state, bad)
                self.assertEqual(self.path.read_bytes(), original)

    def test_unknown_loaded_version_is_not_reset_to_empty_state(self):
        self.raw({**self.manifest, "version": 9})
        with self.assertRaises(ValueError):
            load_manifest(self.state)
        self.assertTrue(self.path.exists())

    def test_missing_reference_cannot_become_default_or_known_good(self):
        for field in ("default", "known_good"):
            with self.subTest(field=field):
                bad = {**self.manifest, field: "dancer-" + "f" * 64 + ".efi"}
                with self.assertRaises(ValueError):
                    validate_manifest(bad)

    def test_image_ids_cannot_escape_or_match_other_image_bytes(self):
        for entry in ("../../outside.efi", "dancer-" + "f" * 64 + ".efi", "dancer-*.efi",
                      "dancer-" + "a" * 64 + ".efi\n"):
            with self.subTest(entry=entry):
                record = self.manifest["images"][A]
                bad = {"version": 1, "default": entry, "known_good": None,
                       "images": {entry: record}}
                with self.assertRaises(ValueError):
                    validate_manifest(bad)

    def test_closure_paths_are_only_unambiguous_top_level_store_entries(self):
        for closure in ("/etc", "relative", "/nix/store/../etc", "/nix/store/" + "a" * 32 + "-x/init",
                        "/nix/store/" + "a" * 32 + "-x\n", "/nix/store/" + "a" * 32 + '-"x'):
            with self.subTest(closure=closure):
                bad = copy.deepcopy(self.manifest)
                bad["images"][A]["closure"] = closure
                with self.assertRaises(ValueError):
                    validate_manifest(bad)

    def test_missing_or_malformed_image_records_are_rejected(self):
        for field, value in (("sha256", "b" * 64), ("pcr_key_fingerprint", "not-a-hash"),
                             ("pcr_key_fingerprint", None), ("closure", None)):
            with self.subTest(field=field, value=value):
                bad = copy.deepcopy(self.manifest)
                bad["images"][A][field] = value
                with self.assertRaises(ValueError):
                    validate_manifest(bad)
        for record in (None, [], {}):
            bad = copy.deepcopy(self.manifest)
            bad["images"][A] = record
            with self.assertRaises(ValueError):
                validate_manifest(bad)

    def test_duplicate_json_keys_are_rejected_instead_of_last_value_winning(self):
        self.path.write_text('{"version":9,"version":1,"default":null,"known_good":null,"images":{}}')
        self.path.chmod(0o600)
        with self.assertRaises(ValueError):
            load_manifest(self.state)

    def test_symlink_manifest_is_neither_followed_nor_replaced(self):
        outside = self.state / "outside"
        outside.write_text("untouched")
        self.path.symlink_to(outside)
        for operation in (lambda: load_manifest(self.state),
                          lambda: write_manifest(self.state, self.manifest)):
            with self.assertRaises(ValueError):
                operation()
        self.assertEqual(outside.read_text(), "untouched")
        self.assertTrue(self.path.is_symlink())

    def test_failed_rename_preserves_old_state_and_removes_only_own_temporary_file(self):
        self.raw(self.manifest)
        original = self.path.read_bytes()
        sentinel = self.state / "unrelated"
        sentinel.write_text("keep")
        new = {**self.manifest, "default": A}
        with patch("secure_uki.publish.os.replace", side_effect=OSError("injected rename failure")):
            with self.assertRaises(OSError):
                write_manifest(self.state, new)
        self.assertEqual(self.path.read_bytes(), original)
        self.assertEqual(sentinel.read_text(), "keep")
        self.assertEqual(set(self.state.iterdir()), {self.path, sentinel})

    def test_durable_write_flushes_file_before_rename_and_directory_after(self):
        events = []
        real_fsync, real_replace = os.fsync, os.replace
        def flush(fd):
            events.append("flush")
            return real_fsync(fd)
        def rename(source, destination):
            events.append("rename")
            return real_replace(source, destination)
        with patch("secure_uki.publish.os.fsync", side_effect=flush), \
             patch("secure_uki.publish.os.replace", side_effect=rename):
            write_manifest(self.state, self.manifest)
        self.assertTrue(self.path.exists())
        self.assertEqual(events, ["flush", "rename", "flush"])

    def test_installer_lock_serializes_and_releases_after_failure(self):
        with installer_lock(self.state):
            with self.assertRaises(BlockingIOError):
                with installer_lock(self.state):
                    self.fail("Concurrent installer acquired the same lock")
        with self.assertRaisesRegex(RuntimeError, "transaction failed"):
            with installer_lock(self.state):
                raise RuntimeError("transaction failed")
        with installer_lock(self.state):
            self.assertEqual((self.state / "installer.lock").stat().st_mode & 0o777, 0o600)

    def test_lock_cannot_follow_symlink_or_use_unsafe_existing_permissions(self):
        outside = self.state / "outside"
        outside.write_text("keep")
        lock = self.state / "installer.lock"
        lock.symlink_to(outside)
        with self.assertRaises((ValueError, OSError)):
            with installer_lock(self.state):
                self.fail("Lock followed a symlink")
        self.assertEqual(outside.read_text(), "keep")
        lock.unlink()
        lock.touch(mode=0o666)
        lock.chmod(0o666)
        with self.assertRaises(ValueError):
            with installer_lock(self.state):
                self.fail("Unsafe existing lock was accepted")

    def test_other_user_writable_state_directory_is_rejected(self):
        self.state.chmod(0o777)
        with self.assertRaises(ValueError):
            write_manifest(self.state, self.manifest)
        self.assertFalse(self.path.exists())
