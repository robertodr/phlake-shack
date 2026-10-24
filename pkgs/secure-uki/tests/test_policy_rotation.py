"""Disposable filesystem/real OpenSSL; PE tools doubled, no host keys or TPM."""

from dataclasses import replace
import errno
import importlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from secure_uki import migration_state as migration
from secure_uki.metadata import Keys
from secure_uki.publish import installer_lock
import test_prepare as fixtures


def rotation_api(name):
    if importlib.util.find_spec("secure_uki.policy_rotation") is None:
        raise AssertionError("atomic policy rotation module missing")
    function = getattr(importlib.import_module("secure_uki.policy_rotation"), name, None)
    if not callable(function):
        raise AssertionError(f"atomic policy rotation API missing: {name}")
    return function


def pair_bytes(path):
    return tuple((path / name).read_bytes() for name in ("private.pem", "public.pem"))


def dummy_pair(path, label):
    path.mkdir(mode=0o700)
    (path / "private.pem").write_bytes(label + b" private")
    (path / "public.pem").write_bytes(label + b" public")
    (path / "private.pem").chmod(0o600)
    (path / "public.pem").chmod(0o644)


class AtomicPairTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.active, self.staged = self.root / "active", self.root / "staged"
        dummy_pair(self.active, b"old")
        dummy_pair(self.staged, b"new")

    def test_real_exchange_keeps_each_whole_pair_and_old_open_directory(self):
        exchange = rotation_api("atomic_pair_exchange")
        old, new = pair_bytes(self.active), pair_bytes(self.staged)
        inode = self.active.stat().st_ino
        fd = os.open(self.active, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            exchange(self.active, self.staged)
            self.assertEqual(pair_bytes(self.active), new)
            self.assertEqual(pair_bytes(self.staged), old)
            self.assertEqual(self.staged.stat().st_ino, inode)
            values = []
            for name in ("private.pem", "public.pem"):
                file_fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=fd)
                with os.fdopen(file_fd, "rb") as file:
                    values.append(file.read())
            self.assertEqual(tuple(values), old)
        finally:
            os.close(fd)

    def test_device_renumbering_preserves_both_pair_snapshot_bindings(self):
        module = importlib.import_module("secure_uki.policy_rotation")
        before = module._pair_snapshot(self.active)
        real_lstat, real_fstat = Path.lstat, os.fstat
        def changed(info):
            values = {name: getattr(info, name) for name in dir(info) if name.startswith("st_")}
            return SimpleNamespace(**{**values, "st_dev": info.st_dev + 1024})
        def lstat(path, *args, **kwargs):
            return changed(real_lstat(path, *args, **kwargs))
        with patch.object(Path, "lstat", lstat), patch.object(os, "fstat", side_effect=lambda fd: changed(real_fstat(fd))):
            self.assertEqual(module._pair_snapshot(self.active), before,
                             "unchanged pair rejected after runtime device renumbering")

    def test_symlink_hardlink_unsafe_permissions_or_extra_files_refuse(self):
        exchange = rotation_api("atomic_pair_exchange")
        before = pair_bytes(self.active)
        self.staged.chmod(0o750)
        with self.assertRaises(ValueError):
            exchange(self.active, self.staged)
        self.staged.chmod(0o700)
        extra = self.staged / "extra"
        extra.write_bytes(b"must not exchange unknown contents")
        with self.assertRaises(ValueError):
            exchange(self.active, self.staged)
        extra.unlink()
        os.link(self.active / "private.pem", extra)
        with self.assertRaises(ValueError):
            exchange(self.active, self.staged)
        extra.unlink()
        self.staged.rename(self.root / "real-staged")
        self.staged.symlink_to(self.root / "real-staged", target_is_directory=True)
        with self.assertRaises(ValueError):
            exchange(self.active, self.staged)
        self.assertEqual(pair_bytes(self.active), before)

    def test_same_directory_or_ancestor_refuses(self):
        exchange = rotation_api("atomic_pair_exchange")
        with self.assertRaises(ValueError):
            exchange(self.active, self.active)
        with self.assertRaises(ValueError):
            exchange(self.root, self.active)

    def test_real_cross_filesystem_refusal_leaves_both_pairs(self):
        exchange = rotation_api("atomic_pair_exchange")
        if not Path("/dev/shm").is_dir():
            self.skipTest("separate tmpfs unavailable")
        with tempfile.TemporaryDirectory(dir="/dev/shm") as tmp:
            staged = Path(tmp) / "staged"
            dummy_pair(staged, b"cross-device")
            if staged.stat().st_dev == self.active.stat().st_dev:
                self.skipTest("test filesystems have same device")
            before = pair_bytes(self.active), pair_bytes(staged)
            with self.assertRaises(ValueError):
                exchange(self.active, staged)
            self.assertEqual((pair_bytes(self.active), pair_bytes(staged)), before)

    def test_unsupported_syscall_never_falls_back_to_separate_renames(self):
        exchange = rotation_api("atomic_pair_exchange")
        module = importlib.import_module("secure_uki.policy_rotation")
        before = pair_bytes(self.active), pair_bytes(self.staged)
        with patch.object(module, "_rename_exchange", side_effect=OSError(errno.ENOSYS, "test unavailable")):
            with self.assertRaises(OSError):
                exchange(self.active, self.staged)
        self.assertEqual((pair_bytes(self.active), pair_bytes(self.staged)), before)

    def test_sync_failure_before_exchange_retains_old_and_after_exchange_retains_both(self):
        exchange = rotation_api("atomic_pair_exchange")
        module = importlib.import_module("secure_uki.policy_rotation")
        before = pair_bytes(self.active), pair_bytes(self.staged)
        with patch.object(module.os, "fsync", side_effect=OSError("synthetic pre-exchange fsync failure")):
            with self.assertRaises(OSError):
                exchange(self.active, self.staged)
        self.assertEqual((pair_bytes(self.active), pair_bytes(self.staged)), before)
        rename = module._rename_exchange
        sync = module.migration._sync_directory
        exchanged = False
        def swap(a, b):
            nonlocal exchanged
            rename(a, b)
            exchanged = True
        def sync_directory(path):
            if exchanged:
                raise OSError("synthetic post-exchange fsync failure")
            return sync(path)
        with patch.object(module, "_rename_exchange", side_effect=swap), \
             patch.object(module.migration, "_sync_directory", side_effect=sync_directory):
            with self.assertRaises(OSError):
                exchange(self.active, self.staged)
        self.assertEqual((pair_bytes(self.active), pair_bytes(self.staged)), before[::-1])

    def test_real_sigkill_around_exchange_retains_whole_pairs_and_blocks_replay(self):
        rotation_api("atomic_pair_exchange")
        script = '''
import os,signal,sys
from pathlib import Path
from secure_uki import policy_rotation as rotation
from secure_uki.publish import installer_lock
active,staged,state = map(Path,sys.argv[1:4]); point=sys.argv[4]
rename = rotation._rename_exchange
sync = rotation.migration._sync_directory
exchanged = False
def swap(a,b):
    global exchanged
    if point == "before": os.kill(os.getpid(),signal.SIGKILL)
    rename(a,b); exchanged=True
    if point == "after": os.kill(os.getpid(),signal.SIGKILL)
def synced(path):
    sync(path)
    if exchanged and point == "post-sync": os.kill(os.getpid(),signal.SIGKILL)
rotation._rename_exchange=swap
rotation.migration._sync_directory=synced
with installer_lock(state): rotation.atomic_pair_exchange(active,staged)
'''
        evidence = {"entry_id": "dancer-" + "a" * 64 + ".efi", "sha256": "a" * 64,
                    "closure": "/nix/store/" + "a" * 32 + "-synthetic", "pcr_key_fingerprint": "b" * 64}
        for point in ("before", "after", "post-sync"):
            with self.subTest(point=point), tempfile.TemporaryDirectory() as tmp:
                state = Path(tmp)
                active, staged = state / "active", state / "staged"
                dummy_pair(active, b"old"); dummy_pair(staged, b"new")
                before = pair_bytes(active), pair_bytes(staged)
                with installer_lock(state):
                    operation = migration.begin_operation(state, "issuer", {"version": 1})
                    migration.record_phase(operation, "prepared", evidence)
                result = subprocess.run([sys.executable, "-B", "-c", script,
                                         str(active), str(staged), str(state), point], capture_output=True, text=True)
                self.assertEqual(result.returncode, -signal.SIGKILL, result.stderr)
                self.assertEqual(result.stdout, "")
                expected = before if point == "before" else before[::-1]
                self.assertEqual((pair_bytes(active), pair_bytes(staged)), expected)
                self.assertEqual(migration.read_operation(operation)["phase"], "prepared")
                with installer_lock(state), self.assertRaises(ValueError):
                    migration.begin_operation(state, "issuer", {"version": 1})
                with self.assertRaises(ValueError):
                    migration.require_writer_allowed(state, "install")

    def test_real_file_and_parent_fsync_surround_exchange(self):
        exchange = rotation_api("atomic_pair_exchange")
        module = importlib.import_module("secure_uki.policy_rotation")
        sync, rename = os.fsync, module._rename_exchange
        events = []
        def fsync(fd):
            events.append("dir" if stat.S_ISDIR(os.fstat(fd).st_mode) else "file")
            return sync(fd)
        def swap(a, b):
            events.append("exchange")
            return rename(a, b)
        with patch.object(module.os, "fsync", side_effect=fsync), patch.object(module, "_rename_exchange", side_effect=swap):
            exchange(self.active, self.staged)
        split = events.index("exchange")
        self.assertGreaterEqual(events[:split].count("file"), 4)
        self.assertGreaterEqual(events[:split].count("dir"), 3)
        self.assertGreaterEqual(events[split + 1:].count("dir"), 3)


class PrepareRotationTests(unittest.TestCase):
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
        fixtures.PrepareTests.setUp(self)
        self.state = self.root / "state"
        self.state.mkdir(mode=0o700)
        self.active = self.state / "pcr-signing"
        self.active.mkdir(mode=0o700)
        for old, new, mode in (("old-private.pem", "private.pem", 0o600), ("old-public.pem", "public.pem", 0o644)):
            shutil.copyfile(self.root / old, self.active / new)
            (self.active / new).chmod(mode)
        self.keys = replace(self.keys, pcr_private=self.active / "private.pem", pcr_public=self.active / "public.pem")
        self.generation = replace(self.generation, closure=Path("/nix/store/" + "a" * 32 + "-disposable-dancer"))
        self.luks = self.state / "header-sentinel"
        self.luks.write_bytes(b"synthetic LUKS header/token unchanged")
        self.luks.chmod(0o600)
        self.operation = self.state / "migrations/issuer"

    def prepare(self, run=None):
        return rotation_api("prepare_rotation")(self.generation, self.tools, self.keys, self.state, run or self.run)

    def test_stages_real_2048_pair_and_verified_candidate_before_any_exchange(self):
        before = pair_bytes(self.active)
        db = self.keys.db_key.read_bytes(), self.keys.db_cert.read_bytes()
        operation = self.prepare()
        self.assertEqual(operation, self.operation)
        value = migration.read_operation(operation)
        self.assertEqual(value["phase"], "prepared")
        staged = operation / "staged-pair"
        info = fixtures.command(["openssl", "pkey", "-pubin", "-in", str(staged / "public.pem"), "-text", "-noout"])
        self.assertIn("Public-Key: (2048 bit)", info)
        evidence = value["receipts"][0]["evidence"]
        candidate = Path(evidence["candidate_path"])
        self.assertTrue(candidate.is_relative_to(operation / "artifacts"))
        self.assertEqual(candidate.name, evidence["entry_id"])
        self.assertEqual(pair_bytes(self.active), before)
        self.assertEqual((self.keys.db_key.read_bytes(), self.keys.db_cert.read_bytes()), db)
        self.assertEqual(self.luks.read_bytes(), b"synthetic LUKS header/token unchanged")
        self.assertEqual(stat.S_IMODE((staged / "private.pem").stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE((staged / "public.pem").stat().st_mode), 0o644)
        self.assertTrue((operation / "attempt.json").exists())
        with self.assertRaises(ValueError):
            self.prepare()
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, "install")
        names = {Path(call[0]).name for call in self.run.calls}
        self.assertFalse(names & {"bootctl", "nix-store", "sbctl", "systemd-cryptenroll", "tpm2_createprimary"})

    def test_runtime_guard_refuses_before_intent_and_rechecks_before_prepared_receipt(self):
        module=importlib.import_module('secure_uki.policy_rotation')
        before=pair_bytes(self.active)
        def reject(stage): raise ValueError('runtime guard drift')
        try:
            with self.assertRaisesRegex(ValueError,'runtime guard drift'):
                module.prepare_rotation(self.generation,self.tools,self.keys,self.state,self.run,guard=reject)
        except TypeError: self.fail('prepare does not enforce locked runtime guard')
        self.assertFalse(self.operation.exists())
        self.assertEqual(pair_bytes(self.active),before)
        def drift_after_prepare(stage):
            if self.operation.exists(): raise ValueError('late runtime drift')
            return {'closure':str(self.generation.closure),'context':'synthetic-private-binding'}
        with self.assertRaisesRegex(ValueError,'late runtime drift'):
            module.prepare_rotation(self.generation,self.tools,self.keys,self.state,self.run,guard=drift_after_prepare)
        self.assertEqual(migration.read_operation(self.operation)['phase'],'intent')
        self.assertEqual(pair_bytes(self.active),before)

    def test_verified_candidate_larger_than_pem_bound_is_accepted(self):
        rotation_api("prepare_rotation")
        def run(argv):
            result = self.run(argv)
            if Path(argv[0]).name == "sbsign":
                output = Path(argv[argv.index("--output") + 1])
                with output.open("ab") as file:
                    file.write(b"disposable-PE-padding" * 2048)
            return result
        try:
            operation = self.prepare(run)
        except ValueError:
            self.fail("verified PE candidate was incorrectly rejected by the PEM size bound")
        self.assertEqual(migration.read_operation(operation)["phase"], "prepared")

    def test_image_failure_retains_staged_pair_intent_and_old_active_pair(self):
        before = pair_bytes(self.active)
        self.run.fail_tool = "ukify"
        with self.assertRaises(RuntimeError):
            self.prepare()
        self.assertEqual(pair_bytes(self.active), before)
        self.assertTrue((self.operation / "staged-pair/private.pem").exists())
        self.assertEqual(migration.read_operation(self.operation)["phase"], "intent")
        with self.assertRaises(ValueError):
            self.prepare()

    def test_failed_image_verification_retains_partial_image_evidence(self):
        rotation_api("prepare_rotation")
        self.run.bad_policy = True
        with self.assertRaises(ValueError):
            self.prepare()
        artifacts = self.operation / "artifacts"
        stages = list(artifacts.glob(".prepare-*"))
        self.assertEqual(len(stages), 1, "failed candidate/evidence was silently deleted")
        self.assertTrue((stages[0] / "signed.efi").is_file())
        self.assertEqual(migration.read_operation(self.operation)["phase"], "intent")

    def test_bad_old_pair_rejected_before_key_generation(self):
        rotation_api("prepare_rotation")
        shutil.copyfile(self.root / "pcr.pem", self.active / "public.pem")
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertFalse((self.operation / "staged-pair").exists())

    def test_old_issuer_must_be_3072_not_already_2048(self):
        rotation_api("prepare_rotation")
        shutil.copyfile(self.root / "pcr.key", self.active / "private.pem")
        shutil.copyfile(self.root / "pcr.pem", self.active / "public.pem")
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertFalse((self.operation / "staged-pair").exists())

    def test_unsafe_active_pair_or_wrong_parent_refuses_before_intent(self):
        rotation_api("prepare_rotation")
        self.active.chmod(0o750)
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertFalse(self.operation.exists())
        self.active.chmod(0o700)
        wrong = Keys(self.keys.db_key, self.keys.db_cert, self.root / "pcr.key", self.root / "pcr.pem")
        with self.assertRaises(ValueError):
            rotation_api("prepare_rotation")(self.generation, self.tools, wrong, self.state, self.run)
        self.assertFalse(self.operation.exists())

    def test_key_generation_failure_leaves_attempt_and_blocks_retry(self):
        rotation_api("prepare_rotation")
        before = pair_bytes(self.active)
        def run(argv):
            if "genpkey" in argv:
                raise RuntimeError("synthetic generation failure")
            return self.run(argv)
        with self.assertRaises(RuntimeError):
            self.prepare(run)
        self.assertTrue((self.operation / "attempt.json").exists())
        self.assertEqual(pair_bytes(self.active), before)
        with self.assertRaises(ValueError):
            self.prepare()

    def test_source_drift_during_image_preparation_refuses_receipt(self):
        rotation_api("prepare_rotation")
        before = pair_bytes(self.active)
        def run(argv):
            if "build" in argv:
                self.generation.kernel.write_bytes(b"changed source")
            return self.run(argv)
        with self.assertRaises(ValueError):
            self.prepare(run)
        self.assertEqual(migration.read_operation(self.operation)["phase"], "intent")
        self.assertEqual(pair_bytes(self.active), before)

    def test_software_runner_rejects_tpm_boot_selection_and_enrollment_commands(self):
        rotation_api("prepare_rotation")
        module = importlib.import_module("secure_uki.policy_rotation")
        calls = []
        run = module._software_runner(self.tools, calls.append)
        for argv in (["tpm2_createprimary"], ["systemd-cryptenroll"], [str(self.tools.bootctl)],
                     [str(self.tools.nix_store)], ["sbctl"]):
            with self.subTest(argv=argv), self.assertRaises(ValueError):
                run(argv)
        self.assertEqual(calls, [])

    def test_unexpected_generated_strength_or_public_mismatch_refuses_prepared_receipt(self):
        rotation_api("prepare_rotation")
        before = pair_bytes(self.active)
        def run(argv):
            if "genpkey" in argv:
                argv = [a.replace("rsa_keygen_bits:2048", "rsa_keygen_bits:3072") for a in argv]
            return self.run(argv)
        with self.assertRaises(ValueError):
            self.prepare(run)
        self.assertEqual(pair_bytes(self.active), before)
        self.assertEqual(migration.read_operation(self.operation)["phase"], "intent")

    def test_real_sigkill_during_generation_key_fsync_and_receipt_never_replays(self):
        rotation_api("prepare_rotation")
        script = '''
import json,os,signal,sys
from pathlib import Path
from secure_uki import policy_rotation as rotation
from secure_uki.metadata import Generation,Keys,Tools
from test_prepare import ImageTools
payload=json.loads(sys.argv[1]); point=payload["point"]
args=payload["generation"]
for field in ("closure","kernel","initrd","init","os_release"): args[field]=Path(args[field])
generation=Generation(**args)
keys=Keys(**{name:Path(value) for name,value in payload["keys"].items()})
tools=Tools(**{name:Path(value) for name,value in payload["tools"].items()})
backend=ImageTools()
def run(argv):
    result=backend(argv)
    if point == "generated" and "genpkey" in argv: os.kill(os.getpid(),signal.SIGKILL)
    return result
snapshot=rotation._pair_snapshot
def snap(path,**kwargs):
    result=snapshot(path,**kwargs)
    if point == "key-fsync" and path.name == "staged-pair" and kwargs.get("sync"):
        os.kill(os.getpid(),signal.SIGKILL)
    return result
record=rotation.migration.record_phase
def phase(*args):
    if point == "before-receipt": os.kill(os.getpid(),signal.SIGKILL)
    result=record(*args)
    if point == "after-receipt": os.kill(os.getpid(),signal.SIGKILL)
    return result
rotation._pair_snapshot=snap
rotation.migration.record_phase=phase
rotation.prepare_rotation(generation,tools,keys,Path(payload["state"]),run)
'''
        for point in ("generated", "key-fsync", "before-receipt", "after-receipt"):
            with self.subTest(point=point), tempfile.TemporaryDirectory(dir=self.root) as tmp:
                state = Path(tmp)
                active = state / "pcr-signing"
                active.mkdir(mode=0o700)
                for name, mode in (("private.pem", 0o600), ("public.pem", 0o644)):
                    shutil.copyfile(self.active / name, active / name)
                    (active / name).chmod(mode)
                keys = replace(self.keys, pcr_private=active / "private.pem", pcr_public=active / "public.pem")
                before = pair_bytes(active)
                payload = {"state": str(state), "point": point,
                           "generation": {name: str(value) for name, value in vars(self.generation).items()},
                           "keys": {name: str(value) for name, value in vars(keys).items()},
                           "tools": {name: str(value) for name, value in vars(self.tools).items()}}
                # unittest adds the tests directory to its own sys.path, not its
                # children's environment (Nix checkPhase supplies only src).
                env = {**os.environ, "PYTHONPATH": str(Path(fixtures.__file__).parent)
                       + os.pathsep + os.environ.get("PYTHONPATH", "")}
                result = subprocess.run([sys.executable, "-B", "-c", script, json.dumps(payload)],
                                        capture_output=True, text=True, env=env)
                self.assertEqual(result.returncode, -signal.SIGKILL, result.stderr)
                self.assertEqual(result.stdout, "")
                self.assertEqual(pair_bytes(active), before)
                operation = state / "migrations/issuer"
                phase = migration.read_operation(operation)["phase"]
                self.assertEqual(phase, "prepared" if point == "after-receipt" else "intent")
                self.assertTrue((operation / "staged-pair/private.pem").exists())
                with self.assertRaises(ValueError):
                    rotation_api("prepare_rotation")(self.generation, self.tools, keys, state, self.run)

    def test_preparation_owns_existing_lock_and_refuses_second_holder_before_intent(self):
        rotation_api("prepare_rotation")
        with installer_lock(self.state), self.assertRaises(BlockingIOError):
            self.prepare()
        self.assertFalse(self.operation.exists())


if __name__ == "__main__":
    unittest.main()
