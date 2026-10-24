"""One-shot rotation publication over real private files and disposable crypto."""

from dataclasses import replace
import importlib
import json
import os
from pathlib import Path
import signal
import shutil
import unittest
from unittest.mock import patch

from secure_uki import migration_state as migration
from secure_uki.publish import confirm_boot, install, load_manifest, write_manifest
from test_policy_rotation import pair_bytes, rotation_api
import test_prepare as fixtures
import test_publish as publication


class RotationCommitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.PrepareTests.setUpClass.__func__(cls)
        root = Path(cls.key_tmp.name)
        fixtures.command(["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:3072",
                          "-out", str(root / "old-private.pem")])
        fixtures.command(["openssl", "pkey", "-in", str(root / "old-private.pem"), "-pubout",
                          "-out", str(root / "old-public.pem")])

    @classmethod
    def tearDownClass(cls):
        fixtures.PrepareTests.tearDownClass.__func__(cls)

    def setUp(self):
        publication.PublicationTests.setUp(self)
        self.active = self.state / "pcr-signing"
        self.active.mkdir(mode=0o700)
        for source, name, mode in (("old-private.pem", "private.pem", 0o600), ("old-public.pem", "public.pem", 0o644)):
            shutil.copyfile(self.root / source, self.active / name)
            (self.active / name).chmod(mode)
        self.keys = replace(self.keys, pcr_private=self.active / "private.pem", pcr_public=self.active / "public.pem")
        self.old = publication.PublicationTests.prepare_candidate(self, "a")
        install(self.old, self.esp, self.state, self.tools, self.keys, self.runner)
        self.loaded = self.old.entry_id
        confirm_boot(self.old.generation.closure, self.esp, self.state, self.run_ready)
        self.before = load_manifest(self.state)
        self.old_bytes = pair_bytes(self.active)
        self.generation = self.old.generation
        self.events.clear()

    # Used by PublicationTests.setUp to generate its initial disposable image.
    prepare_candidate = publication.PublicationTests.prepare_candidate

    def run_ready(self, argv):
        tool = Path(argv[0]).name
        if tool == "bootctl" and "--print-stub-path" in argv:
            return str(self.images / self.loaded)
        if tool == "systemctl":
            if "is-active" in argv:
                return "active"
            if "is-system-running" in argv:
                return "running"
            values = {"ActiveState": "active", "SubState": "exited", "Result": "success", "ExecMainStatus": "0"}
            return values[argv[argv.index("-p") + 1]]
        return self.runner(argv)

    def prepare(self):
        return rotation_api("prepare_rotation")(self.generation, self.tools, self.keys, self.state, self.run_ready)

    def commit(self, operation):
        return rotation_api("commit_rotation")(operation, self.generation, self.tools,
                                                self.keys, self.esp, self.state, self.run_ready)

    def accept(self, operation, *, attested=True):
        with patch("secure_uki.policy_rotation.read_generation", return_value=self.generation):
            return rotation_api("accept_rotation")(operation, self.loaded, self.generation.closure,
                                                    self.esp, self.state, self.run_ready,
                                                    tools=self.tools, keys=self.keys,
                                                    manual_unlock_attested=attested)

    def test_commit_exchanges_once_publishes_without_confirming_and_retains_recovery(self):
        rotation_api("commit_rotation")
        operation = self.prepare()
        staged = pair_bytes(operation / "staged-pair")
        manifest = self.commit(operation)
        self.assertEqual(pair_bytes(self.active), staged)
        self.assertEqual(pair_bytes(operation / "staged-pair"), self.old_bytes)
        self.assertEqual(migration.read_operation(operation)["phase"], "published")
        self.assertEqual(manifest["known_good"], self.old.entry_id)
        self.assertNotEqual(manifest["default"], self.old.entry_id)
        self.assertTrue((self.images / self.old.entry_id).exists())
        self.assertTrue((operation / "commit-attempt.json").exists())
        with self.assertRaises(ValueError):
            self.commit(operation)
        self.assertEqual(pair_bytes(self.active), staged)

    def test_commit_runtime_drift_refuses_swap_and_retains_permanent_attempt(self):
        module=importlib.import_module('secure_uki.policy_rotation'); operation=self.prepare()
        calls=[]
        def late_drift(stage):
            calls.append(stage)
            if len(calls)==2: raise ValueError('late accepted runtime drift')
        try:
            with self.assertRaisesRegex(ValueError,'late accepted runtime drift'):
                module.commit_rotation(operation,self.generation,self.tools,self.keys,self.esp,self.state,self.run_ready,guard=late_drift)
        except TypeError: self.fail('commit does not enforce locked runtime guard')
        self.assertEqual(pair_bytes(self.active),self.old_bytes)
        self.assertTrue((operation/'commit-attempt.json').exists())
        self.assertEqual(migration.read_operation(operation)['phase'],'prepared')
        with self.assertRaises(ValueError): self.commit(operation)

    def test_post_publication_guard_failure_never_records_published_or_completion(self):
        module=importlib.import_module('secure_uki.policy_rotation'); operation=self.prepare()
        def drift(stage):
            if stage=='published': raise ValueError('post-publication trust drift')
        try:
            with self.assertRaisesRegex(ValueError,'post-publication trust drift'):
                module.commit_rotation(operation,self.generation,self.tools,self.keys,self.esp,self.state,self.run_ready,guard=drift)
        except TypeError: self.fail('publication does not enforce post-write guard')
        self.assertEqual(migration.read_operation(operation)['phase'],'exchanged')
        self.assertNotEqual(pair_bytes(self.active),self.old_bytes)
        with self.assertRaises(ValueError): migration.require_writer_allowed(self.state,'install')
        self.assertTrue((self.images/self.old.entry_id).exists())

    def test_publication_failure_never_completes_or_replays_key_exchange(self):
        rotation_api("commit_rotation")
        operation = self.prepare()
        self.runner.fail_on = "select-default"
        with self.assertRaises(OSError):
            self.commit(operation)
        self.assertEqual(migration.read_operation(operation)["phase"], "exchanged")
        new = pair_bytes(self.active)
        self.assertEqual(pair_bytes(operation / "staged-pair"), self.old_bytes)
        with self.assertRaises(ValueError):
            self.commit(operation)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, "install")
        self.assertEqual(pair_bytes(self.active), new)
        self.assertTrue((self.images / self.old.entry_id).exists())

    def test_commit_marker_before_exchange_prevents_retry_even_if_no_swap_occurred(self):
        rotation_api("commit_rotation")
        operation = self.prepare()
        module = importlib.import_module("secure_uki.policy_rotation")
        with patch.object(module, "atomic_pair_exchange", side_effect=OSError("synthetic exchange failure")):
            with self.assertRaises(OSError):
                self.commit(operation)
        marker = (operation / "commit-attempt.json").read_bytes()
        with self.assertRaises(ValueError):
            self.commit(operation)
        self.assertEqual(pair_bytes(self.active), self.old_bytes)
        self.assertEqual((operation / "commit-attempt.json").read_bytes(), marker)

    def test_real_sigkill_exchange_and_publication_boundaries_block_all_replay(self):
        rotation_api("commit_rotation")
        for boundary in ("before-exchange", "after-exchange", "candidate-copy", "manager-copy", "default", "manifest", "journal-clear"):
            with self.subTest(boundary=boundary):
                if boundary != "before-exchange":
                    self.setUp()  # Fresh isolated one-shot fixture, never repair/retry killed state.
                operation = self.prepare()
                staged = pair_bytes(operation / "staged-pair")
                candidate_entry = migration.read_operation(operation)["receipts"][0]["evidence"]["entry_id"]
                pid = os.fork()
                if pid == 0:
                    def killed(*_args, **_kwargs):
                        os.kill(os.getpid(), signal.SIGKILL)
                    try:
                        rotation = importlib.import_module("secure_uki.policy_rotation")
                        publisher = importlib.import_module("secure_uki.publish")
                        if boundary in {"before-exchange", "after-exchange"}:
                            original = rotation.atomic_pair_exchange
                            def exchange(*args, **kwargs):
                                if boundary == "before-exchange":
                                    killed()
                                original(*args, **kwargs)
                                killed()
                            rotation.atomic_pair_exchange = exchange
                        else:
                            target = {"candidate-copy": "_publish_file", "manager-copy": "_publish_file", "default": "_select",
                                      "manifest": "write_manifest", "journal-clear": "_flush_directory"}[boundary]
                            original = getattr(publisher, target)
                            def checkpoint(*args, **kwargs):
                                result = original(*args, **kwargs)
                                if ((boundary == "candidate-copy" and Path(args[1]).name == candidate_entry)
                                        or (boundary == "manager-copy" and Path(args[1]) == self.esp / "EFI/systemd/systemd-bootx64.efi")
                                        or (boundary == "journal-clear" and args[0] == self.state
                                            and not (self.state / "journal.json").exists())
                                        or boundary in {"default", "manifest"}):
                                    killed()
                                return result
                            setattr(publisher, target, checkpoint)
                        self.commit(operation)
                    except BaseException:
                        os._exit(91)
                    os._exit(92)
                _, status = os.waitpid(pid, 0)
                self.assertTrue(os.WIFSIGNALED(status), "child did not reach actual kill checkpoint")
                self.assertEqual(os.WTERMSIG(status), signal.SIGKILL)
                self.assertTrue((operation / "commit-attempt.json").exists())
                self.assertEqual(pair_bytes(self.active), self.old_bytes if boundary == "before-exchange" else staged)
                self.assertEqual(pair_bytes(operation / "staged-pair"), staged if boundary == "before-exchange" else self.old_bytes)
                self.assertTrue((self.images / self.old.entry_id).exists())
                with self.assertRaises(ValueError):
                    self.commit(operation)
                with self.assertRaises(ValueError):
                    migration.require_writer_allowed(self.state, "install")

    def test_boolean_or_foreign_publication_waiver_is_never_accepted(self):
        operation = self.prepare()
        self.events.clear()
        publisher = importlib.import_module("secure_uki.publish")
        for bogus in (True, False, operation, object()):
            with self.subTest(permit=type(bogus).__name__):
                with self.assertRaises(ValueError):
                    publisher._install_locked(self.old, self.esp, self.state, self.tools,
                                              self.keys, self.runner, maintenance=bogus)
        self.assertEqual(self.events, [])
        self.assertEqual(pair_bytes(self.active), self.old_bytes)

    def test_failed_confirmation_or_changed_published_bytes_cannot_be_accepted(self):
        operation = self.prepare()
        self.loaded = self.commit(operation)["default"]
        confirm_boot(self.generation.closure, self.esp, self.state, self.run_ready)
        with patch("secure_uki.policy_rotation._boot_id", return_value="synthetic-next-boot"):
            original = self.run_ready
            def unsuccessful(argv):
                if Path(argv[0]).name == "systemctl" and "SubState" in argv:
                    return "failed"
                return original(argv)
            with patch.object(self, "run_ready", unsuccessful):
                with self.assertRaises(ValueError):
                    self.accept(operation)
            image = self.images / self.loaded
            image.write_bytes(b"tampered signed image")
            with self.assertRaises(ValueError):
                self.accept(operation)
        self.assertEqual(migration.read_operation(operation)["phase"], "published")
        self.assertTrue((operation / "attempt.json").exists())

    def test_changed_manifest_or_candidate_refuses_before_exchange(self):
        rotation_api("commit_rotation")
        operation = self.prepare()
        prepared = migration.read_operation(operation)["receipts"][0]["evidence"]
        Path(prepared["candidate_path"]).write_bytes(b"changed image")
        with self.assertRaises(ValueError):
            self.commit(operation)
        self.assertEqual(pair_bytes(self.active), self.old_bytes)

    def test_old_image_same_closure_cannot_confirm_or_accept_rotation(self):
        rotation_api("accept_rotation")
        operation = self.prepare()
        self.commit(operation)
        with self.assertRaises(ValueError):
            confirm_boot(self.generation.closure, self.esp, self.state, self.run_ready)
        with self.assertRaises(ValueError):
            self.accept(operation)
        self.assertEqual(migration.read_operation(operation)["phase"], "published")

    def test_accept_requires_new_boot_manual_attestation_and_successful_confirmation(self):
        rotation_api("accept_rotation")
        operation = self.prepare()
        manifest = self.commit(operation)
        self.loaded = manifest["default"]
        confirm_boot(self.generation.closure, self.esp, self.state, self.run_ready)
        with self.assertRaises(ValueError):
            self.accept(operation)
        module = importlib.import_module("secure_uki.policy_rotation")
        with patch.object(module, "_boot_id", return_value="synthetic-next-boot"):
            with self.assertRaises(ValueError):
                self.accept(operation, attested=False)
            receipt = self.accept(operation)
        self.assertTrue(receipt.is_file())
        self.assertEqual(migration.read_operation(operation)["phase"], "complete")
        with self.assertRaises(ValueError):
            self.accept(operation)
        migration.require_writer_allowed(self.state, "install")

    def test_confirmation_header_trust_guard_refuses_before_known_good_promotion(self):
        operation=self.prepare(); self.loaded=self.commit(operation)['default']
        before=load_manifest(self.state)
        def drift(stage): raise ValueError('confirmation header/trust drift')
        try:
            with self.assertRaisesRegex(ValueError,'confirmation header/trust drift'):
                confirm_boot(self.generation.closure,self.esp,self.state,self.run_ready,guard=drift)
        except TypeError: self.fail('confirmation lacks locked maintenance guard')
        self.assertEqual(load_manifest(self.state),before)
        self.assertEqual(migration.read_operation(operation)['phase'],'published')

    def test_accept_runtime_drift_after_crypto_never_writes_acceptance_receipt(self):
        module=importlib.import_module('secure_uki.policy_rotation'); operation=self.prepare()
        self.loaded=self.commit(operation)['default']
        confirm_boot(self.generation.closure,self.esp,self.state,self.run_ready)
        calls=[]
        def drift(stage):
            calls.append(stage)
            if len(calls)==2: raise ValueError('final acceptance header drift')
        with patch.object(module,'_boot_id',return_value='synthetic-next-boot'), \
                patch.object(module,'read_generation',return_value=self.generation):
            try:
                with self.assertRaisesRegex(ValueError,'final acceptance header drift'):
                    module.accept_rotation(operation,self.loaded,self.generation.closure,self.esp,self.state,self.run_ready,
                                           tools=self.tools,keys=self.keys,manual_unlock_attested=True,guard=drift)
            except TypeError: self.fail('acceptance does not enforce final runtime guard')
        self.assertEqual(migration.read_operation(operation)['phase'],'published')
        self.assertFalse((operation/'0004-manual-boot-accepted.json').exists())

    def test_completed_rotation_retains_original_image_after_further_update_and_boot(self):
        rotation_api("accept_rotation")
        operation = self.prepare()
        self.loaded = self.commit(operation)["default"]
        confirm_boot(self.generation.closure, self.esp, self.state, self.run_ready)
        module = importlib.import_module("secure_uki.policy_rotation")
        with patch.object(module, "_boot_id", return_value="synthetic-next-boot"):
            self.accept(operation)
        next_image = self.prepare_candidate("d")
        manifest = install(next_image, self.esp, self.state, self.tools, self.keys, self.runner)
        self.assertIn(self.old.entry_id, manifest["images"])
        self.assertTrue((self.state / "gc-roots" / self.old.entry_id).is_symlink())


if __name__ == "__main__":
    unittest.main()
