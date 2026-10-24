"""Real disposable owner-only state; no host evidence, keys or TPM access."""

import copy
import hashlib
import json
import os
from pathlib import Path
import stat
import signal
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from secure_uki import migration_state as migration
from secure_uki.publish import installer_lock

ENTRY = "dancer-" + "a" * 64 + ".efi"
CANDIDATE = {"entry_id": ENTRY, "closure": "/nix/store/" + "a" * 32 + "-system-dancer",
             "sha256": "a" * 64, "pcr_key_fingerprint": "b" * 64}


class MigrationStateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name)
        self.state.chmod(0o700)

    def api(self, name):
        function = getattr(migration, name, None)
        self.assertTrue(callable(function), f"durable migration API missing: {name}")
        return function

    def begin(self, kind="issuer"):
        with installer_lock(self.state):
            return self.api("begin_operation")(self.state, kind, {"version": 1})

    def record(self, operation, phase, evidence=None):
        with installer_lock(self.state):
            return self.api("record_phase")(operation, phase, copy.deepcopy(CANDIDATE if evidence is None else evidence))

    def published(self):
        operation = self.begin()
        for phase in ("prepared", "exchanged", "published"):
            self.record(operation, phase)
        return operation

    def read(self, operation):
        return self.api("read_operation")(operation)

    def test_legacy_absence_is_read_only_and_unknown_actions_refuse(self):
        before = list(self.state.iterdir())
        migration.require_writer_allowed(self.state, "install")
        self.assertEqual(list(self.state.iterdir()), before)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, "force")

    def test_second_attempt_preserves_original_intent_even_after_completion(self):
        operation = self.published()
        self.record(operation, "manual-boot-accepted")
        self.record(operation, "complete")
        before = (operation / "attempt.json").read_bytes()
        with self.assertRaises(ValueError):
            self.begin()
        self.assertEqual((operation / "attempt.json").read_bytes(), before)

    def test_intent_and_receipts_are_private_and_bound_to_state(self):
        operation = self.begin()
        receipt = self.record(operation, "prepared")
        self.assertEqual(stat.S_IMODE(operation.stat().st_mode), 0o700)
        for path in (operation / "attempt.json", receipt):
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        value = self.read(operation)
        self.assertEqual(value["phase"], "prepared")
        self.assertEqual(value["kind"], "issuer")
        self.assertEqual(value["before"], {"version": 1})
        self.assertEqual(value["receipts"][0]["evidence"], CANDIDATE)

    def test_receipts_bind_previous_exact_bytes(self):
        operation = self.begin()
        receipt = self.record(operation, "prepared")
        previous = hashlib.sha256(receipt.read_bytes()).hexdigest()
        next_receipt = self.record(operation, "exchanged")
        self.assertEqual(json.loads(next_receipt.read_bytes())["previous_sha256"], previous)

    def test_pending_intent_blocks_all_writers(self):
        self.begin()
        for action in ("install", "cleanup", "prune", "reconcile", "confirm-boot"):
            with self.subTest(action=action), self.assertRaises(ValueError):
                migration.require_writer_allowed(self.state, action, ENTRY)

    def test_published_allows_only_exact_candidate_confirmation(self):
        self.published()
        migration.require_writer_allowed(self.state, "confirm-boot", ENTRY)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, "confirm-boot", "dancer-" + "c" * 64 + ".efi")
        for action in ("install", "cleanup", "prune", "reconcile"):
            with self.subTest(action=action), self.assertRaises(ValueError):
                migration.require_writer_allowed(self.state, action)

    def test_complete_releases_barrier_not_history(self):
        operation = self.published()
        self.record(operation, "manual-boot-accepted")
        self.record(operation, "complete")
        for action in ("install", "cleanup", "prune", "reconcile", "confirm-boot"):
            migration.require_writer_allowed(self.state, action)
        self.assertTrue((operation / "attempt.json").exists())
        self.assertEqual(self.read(operation)["phase"], "complete")

    def test_phase_skip_repeat_and_regression_refuse_without_new_files(self):
        operation = self.begin()
        with self.assertRaises(ValueError):
            self.record(operation, "complete")
        self.record(operation, "prepared")
        before = sorted(path.name for path in operation.iterdir())
        for phase in ("prepared", "intent", "published", "unexpected"):
            with self.subTest(phase=phase), self.assertRaises(ValueError):
                self.record(operation, phase)
        self.assertEqual(sorted(path.name for path in operation.iterdir()), before)

    def test_changed_candidate_receipt_refuses(self):
        operation = self.begin()
        self.record(operation, "prepared")
        for field, replacement in (("sha256", "c" * 64), ("pcr_key_fingerprint", "c" * 64),
                                   ("closure", "/nix/store/" + "b" * 32 + "-other"),
                                   ("entry_id", "dancer-" + "c" * 64 + ".efi")):
            bad = {**CANDIDATE, field: replacement}
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.record(operation, "exchanged", bad)

    def test_invalid_candidate_contract_refuses_before_phase_write(self):
        operation = self.begin()
        for bad in ({}, {**CANDIDATE, "sha256": "z" * 64}, {**CANDIDATE, "closure": "/tmp/system"},
                    {**CANDIDATE, "entry_id": "dancer-" + "b" * 64 + ".efi"}):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                self.record(operation, "prepared", bad)
        self.assertEqual(list(operation.iterdir()), [operation / "attempt.json"])

    def test_unknown_kind_or_non_json_before_refuses_before_directory_creation(self):
        begin = self.api("begin_operation")
        for kind, before in (("../issuer", {"version": 1}), ("force", {}), ("issuer", {}),
                             ("issuer", {"version": True}), ("issuer", {"version": 1, "data": float("nan")}),
                             ("issuer", {"version": 1, "huge": "x" * 100000})):
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                begin(self.state, kind, before)
        self.assertFalse((self.state / "migrations").exists())

    def test_two_active_kinds_cannot_bypass_global_barrier(self):
        self.begin()
        with self.assertRaises(ValueError):
            self.begin("parent")
        self.assertFalse((self.state / "migrations/parent").exists())

    def test_parent_or_enrollment_intent_never_allows_confirmation(self):
        for kind in ("parent", "enrollment"):
            with tempfile.TemporaryDirectory() as tmp:
                state = Path(tmp)
                with installer_lock(state):
                    self.api("begin_operation")(state, kind, {"version": 1})
                with self.assertRaises(ValueError):
                    migration.require_writer_allowed(state, "confirm-boot", ENTRY)

    def test_verified_enrollment_allows_only_bound_confirmation_without_completing(self):
        operation = self.begin("enrollment")
        self.record(operation, "token-written")
        self.record(operation, "token-verified")
        before = {path.name: path.read_bytes() for path in operation.iterdir()}
        try:
            migration.require_confirmation_binding(self.state, ENTRY, CANDIDATE)
        except ValueError:
            self.fail("verified enrollment blocked its recorded image's normal boot confirmation")
        self.assertEqual(self.read(operation)["phase"], "token-verified")
        self.assertEqual({path.name: path.read_bytes() for path in operation.iterdir()}, before)
        for action in ("install", "cleanup", "prune", "reconcile"):
            with self.subTest(action=action), self.assertRaises(ValueError):
                migration.require_writer_allowed(self.state, action)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, "confirm-boot", "dancer-" + "c" * 64 + ".efi")
        for field, value in (("closure", "/nix/store/" + "b" * 32 + "-other"),
                             ("sha256", "c" * 64), ("pcr_key_fingerprint", "c" * 64)):
            with self.subTest(field=field), self.assertRaises(ValueError):
                migration.require_confirmation_binding(self.state, ENTRY, {**CANDIDATE, field: value})

    def test_enrollment_intent_written_and_uncertain_acceptance_block_confirmation(self):
        operation = self.begin("enrollment")
        for phase in ("intent", "token-written", "token-verified", "attended-boot-accepted"):
            if phase != "intent":
                self.record(operation, phase)
            if phase == "token-verified":
                continue
            with self.subTest(phase=phase), self.assertRaises(ValueError):
                migration.require_confirmation_binding(self.state, ENTRY, CANDIDATE)

    def test_parent_verification_never_grants_boot_confirmation(self):
        operation = self.begin("parent")
        for phase in ("transient-verified", "persistent-verified"):
            self.record(operation, phase, {"observed": phase})
            with self.subTest(phase=phase), self.assertRaises(ValueError):
                migration.require_writer_allowed(self.state, "confirm-boot", ENTRY)

    def test_enrollment_receipt_requires_valid_candidate_before_writing(self):
        malformed = ({"observed": "token"},
                     {key: value for key, value in CANDIDATE.items() if key != "entry_id"},
                     {**CANDIDATE, "closure": "/tmp/system"},
                     {**CANDIDATE, "sha256": "c" * 64},
                     {**CANDIDATE, "pcr_key_fingerprint": "invalid"})
        for index, evidence in enumerate(malformed):
            with self.subTest(case=index):
                state = self.state / str(index)
                state.mkdir(mode=0o700)
                with installer_lock(state):
                    operation = migration.begin_operation(state, "enrollment", {"version": 1})
                    before = (operation / "attempt.json").read_bytes()
                    with self.assertRaises(ValueError):
                        migration.record_phase(operation, "token-written", evidence)
                self.assertEqual(list(operation.iterdir()), [operation / "attempt.json"])
                self.assertEqual((operation / "attempt.json").read_bytes(), before)

    def test_enrollment_candidate_cannot_change_between_receipts(self):
        changed = ({**CANDIDATE, "entry_id": "dancer-" + "c" * 64 + ".efi", "sha256": "c" * 64},
                   {**CANDIDATE, "closure": "/nix/store/" + "b" * 32 + "-other"},
                   {**CANDIDATE, "pcr_key_fingerprint": "c" * 64})
        for index, evidence in enumerate(changed):
            with self.subTest(case=index):
                state = self.state / str(index)
                state.mkdir(mode=0o700)
                with installer_lock(state):
                    operation = migration.begin_operation(state, "enrollment", {"version": 1})
                    migration.record_phase(operation, "token-written", CANDIDATE)
                    before = {path.name: path.read_bytes() for path in operation.iterdir()}
                    with self.assertRaises(ValueError):
                        migration.record_phase(operation, "token-verified", evidence)
                self.assertEqual({path.name: path.read_bytes() for path in operation.iterdir()}, before)

    def test_unbound_existing_enrollment_receipt_is_refused_not_rewritten(self):
        operation = self.begin("enrollment")
        intent = operation / "attempt.json"
        receipt = operation / "0001-token-written.json"
        receipt.write_text(json.dumps({"version": 1, "kind": "enrollment", "sequence": 1,
            "phase": "token-written", "previous_sha256": hashlib.sha256(intent.read_bytes()).hexdigest(),
            "evidence": {"observed": "token"}}))
        receipt.chmod(0o600)
        before = receipt.read_bytes()
        with self.assertRaises(ValueError):
            self.read(operation)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, "confirm-boot", ENTRY)
        self.assertEqual(receipt.read_bytes(), before)

    def test_completed_enrollment_preserves_history_and_releases_writer_barrier(self):
        operation = self.begin("enrollment")
        for phase in ("token-written", "token-verified", "attended-boot-accepted", "complete"):
            self.record(operation, phase)
        before = {path.name: path.read_bytes() for path in operation.iterdir()}
        for action in ("install", "cleanup", "prune", "reconcile", "confirm-boot"):
            migration.require_writer_allowed(self.state, action)
        self.assertEqual({path.name: path.read_bytes() for path in operation.iterdir()}, before)

    def test_missing_intent_unknown_child_or_symlink_fails_closed(self):
        root = self.state / "migrations"
        root.mkdir(mode=0o700)
        child = root / "issuer"
        child.mkdir(mode=0o700)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, "install")
        child.rmdir()
        (root / "unrecognized").mkdir(mode=0o700)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, "install")
        (root / "unrecognized").rmdir()
        child.symlink_to(self.state, target_is_directory=True)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, "install")

    def test_symlinked_migration_root_refuses_without_traversal(self):
        (self.state / "migrations").symlink_to(self.state, target_is_directory=True)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, "install")

    def test_state_symlink_ancestor_and_unsafe_modes_refuse(self):
        root = self.state / "real"
        root.mkdir(mode=0o700)
        (self.state / "alias").symlink_to(root, target_is_directory=True)
        subdir = root / "state"
        subdir.mkdir(mode=0o700)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state / "alias/state", "install")
        self.state.chmod(0o750)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, "install")

    def test_intent_symlink_hardlink_or_unsafe_mode_refuses(self):
        operation = self.begin()
        intent = operation / "attempt.json"
        intent.chmod(0o644)
        with self.assertRaises(ValueError):
            self.read(operation)
        intent.chmod(0o600)
        link = self.state / "hardlink"
        os.link(intent, link)
        with self.assertRaises(ValueError):
            self.read(operation)
        link.unlink()
        backup = self.state / "saved.json"
        intent.rename(backup)
        intent.symlink_to(backup)
        with self.assertRaises(ValueError):
            self.read(operation)

    def test_bounded_duplicate_or_invalid_json_refuses_read_and_write(self):
        operation = self.begin()
        intent = operation / "attempt.json"
        for data in (b'{"version":1,"version":1}', b'{"before":NaN}', b'{', b'x' * 100000):
            intent.write_bytes(data)
            with self.subTest(data=data[:30]), self.assertRaises(ValueError):
                self.read(operation)
            with self.assertRaises(ValueError):
                self.record(operation, "prepared")

    def test_receipt_tampering_gap_or_unrecognized_artifact_refuses(self):
        operation = self.begin()
        prepared = self.record(operation, "prepared")
        exchanged = self.record(operation, "exchanged")
        data = json.loads(prepared.read_bytes())
        data["evidence"]["pcr_key_fingerprint"] = "e" * 64
        prepared.write_text(json.dumps(data))
        with self.assertRaises(ValueError):
            self.read(operation)
        prepared.unlink()
        with self.assertRaises(ValueError):
            self.read(operation)
        exchanged.unlink()
        (operation / "unknown").write_bytes(b"unknown")
        with self.assertRaises(ValueError):
            self.read(operation)

    def test_runtime_device_renumbering_preserves_intent_and_writer_barrier(self):
        operation = self.begin()
        raw = (operation / "attempt.json").read_bytes()
        real_lstat, real_fstat = Path.lstat, os.fstat
        def changed(info):
            values = {name: getattr(info, name) for name in dir(info) if name.startswith("st_")}
            return SimpleNamespace(**{**values, "st_dev": info.st_dev + 1024})
        def lstat(path, *args, **kwargs):
            return changed(real_lstat(path, *args, **kwargs))
        with patch.object(Path, "lstat", lstat), patch.object(os, "fstat", side_effect=lambda fd: changed(real_fstat(fd))):
            try:
                self.assertEqual(self.read(operation)["phase"], "intent")
            except ValueError:
                self.fail("legitimate device renumbering rejected unchanged filesystem/inode intent")
            with self.assertRaises(ValueError):
                migration.require_writer_allowed(self.state, "install")
        self.assertEqual((operation / "attempt.json").read_bytes(), raw)

    def test_legacy_device_bound_receipt_is_not_rewritten_or_accepted(self):
        operation = self.begin()
        intent = operation / "attempt.json"
        record = json.loads(intent.read_bytes())
        record["state_binding"] = {"device": self.state.stat().st_dev, "inode": self.state.stat().st_ino}
        record["operation_binding"] = {"device": operation.stat().st_dev, "inode": operation.stat().st_ino}
        intent.write_text(json.dumps(record))
        before = intent.read_bytes()
        with self.assertRaises(ValueError):
            self.read(operation)
        self.assertEqual(intent.read_bytes(), before)

    def test_state_rebinding_refuses(self):
        operation = self.begin()
        other = self.state / "other"
        other.mkdir(mode=0o700)
        (other / "migrations").mkdir(mode=0o700)
        operation.rename(other / "migrations/issuer")
        with self.assertRaises(ValueError):
            self.read(other / "migrations/issuer")

    def test_replacement_between_metadata_check_and_open_refuses(self):
        operation = self.begin()
        intent = operation / "attempt.json"
        raw = intent.read_bytes()
        real = os.open
        replaced = False
        def open_file(path, flags, *args, **kwargs):
            nonlocal replaced
            if Path(path) == intent and not replaced:
                replaced = True
                intent.rename(self.state / "original-intent.json")
                intent.write_bytes(raw)
                intent.chmod(0o600)
            return real(path, flags, *args, **kwargs)
        with patch.object(migration.os, "open", side_effect=open_file), self.assertRaises(ValueError):
            self.read(operation)

    def test_sigkill_after_intent_file_fsync_blocks_replay_and_writers(self):
        script = '''
import os,signal,sys
from pathlib import Path
from secure_uki import migration_state as migration
from secure_uki.publish import installer_lock
original = migration._sync_directory
def sync(path):
    if path.name == "issuer":
        os.kill(os.getpid(), signal.SIGKILL)
    original(path)
migration._sync_directory = sync
state = Path(sys.argv[1])
with installer_lock(state):
    migration.begin_operation(state, "issuer", {"version": 1})
'''
        result = subprocess.run([sys.executable, "-B", "-c", script, str(self.state)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, -signal.SIGKILL)
        operation = self.state / "migrations/issuer"
        before = (operation / "attempt.json").read_bytes()
        with self.assertRaises(ValueError):
            self.begin()
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, "install")
        self.assertEqual((operation / "attempt.json").read_bytes(), before)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")

    def test_file_and_directory_fsync_precede_intent_success(self):
        real = os.fsync
        calls = []
        def fsync(fd):
            calls.append(stat.S_ISDIR(os.fstat(fd).st_mode))
            return real(fd)
        with patch.object(migration.os, "fsync", side_effect=fsync):
            operation = self.begin()
        self.assertIn(False, calls)
        self.assertTrue(calls[-1])
        self.assertEqual(self.read(operation)["phase"], "intent")

    def test_fsync_failure_retains_attempt_and_prevents_replay(self):
        real = os.fsync
        def fsync(fd):
            if stat.S_ISREG(os.fstat(fd).st_mode):
                raise OSError("disposable injected durability failure")
            return real(fd)
        with patch.object(migration.os, "fsync", side_effect=fsync), self.assertRaises(OSError):
            self.begin()
        operation = self.state / "migrations/issuer"
        self.assertTrue((operation / "attempt.json").exists())
        before = (operation / "attempt.json").read_bytes()
        with self.assertRaises(ValueError):
            self.begin()
        self.assertEqual((operation / "attempt.json").read_bytes(), before)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, "install")


if __name__ == "__main__":
    unittest.main()
