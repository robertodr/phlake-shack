"""Private disposable state and TPM command model; never physical TPM access."""
import copy
import importlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import struct
import tempfile
import unittest
from unittest.mock import patch

from secure_uki import migration_state as migration, tpm_parent
from secure_uki.publish import installer_lock
from test_maintenance import snapshot
from test_tpm_parent import ecc_public

# Synthetic selectors only. No physical slot recommendation.
HANDLE = 0x81000042
DEFAULT = 0x81000001
TOOLS = '/nix/store/' + 'a' * 32 + '-tpm2-tools-5.7/bin'


def module():
    if importlib.util.find_spec('secure_uki.parent_maintenance') is None:
        raise AssertionError('separate parent maintenance approval API missing')
    return importlib.import_module('secure_uki.parent_maintenance')


def private_bytes(path, raw):
    path.write_bytes(raw)
    path.chmod(0o600)


class TpmModel:
    """Models persistent/transient/public/NV effects, including collision refusal."""
    def __init__(self, state):
        self.state = state
        self.persistent = {DEFAULT: b'synthetic existing RSA public'}
        self.nv = {0x01800001: 'synthetic NV metadata'}
        self.created = {}
        self.mutations = []
        self.calls = []
        self.failure = None
        self.owner_auth_set = False
        self.tool_group_mode = False

    def output(self, path, raw):
        existed = path.exists()
        path.write_bytes(raw)
        if not existed:
            path.chmod(0o660 if self.tool_group_mode else 0o600)

    def __call__(self, settings, argv):
        self.calls.append(tuple(argv))
        assert settings['tpm_tools'] == TOOLS
        assert argv[1:3] == ['-T', 'device:/dev/tpmrm0']
        tool = argv[0]
        if tool == 'tpm2_getcap':
            if argv[-1] == 'properties-variable':
                return f'TPM2_PT_PERMANENT:\n  ownerAuthSet:              {int(self.owner_auth_set)}\n'
            values = self.persistent if argv[-1] == 'handles-persistent' else self.nv
            return ''.join(f'- 0x{value:X}\n' for value in sorted(values))
        if tool == 'tpm2_nvreadpublic':
            return self.nv[int(argv[-1], 16)]
        if tool == 'tpm2_readpublic':
            source = argv[argv.index('-c') + 1]
            raw = self.persistent[int(source, 16)] if source.startswith('0x') else self.created[source]
            self.output(Path(argv[argv.index('-o') + 1]), raw)
            return 'synthetic public observation'
        if tool == 'tpm2_createprimary':
            operation = self.state / 'migrations/parent'
            assert migration.read_operation(operation)['phase'] == 'intent'
            assert (operation / 'attempt.json').stat().st_mode & 0o777 == 0o600
            assert '-P' not in argv and '-p' not in argv
            assert argv[argv.index('-G') + 1] == 'ecc256:null:aes128cfb'
            assert argv[argv.index('-g') + 1] == 'sha256'
            assert argv[argv.index('-a') + 1] == '0x30472'
            self.mutations.append('create')
            if self.failure == 'owner-auth':
                raise RuntimeError('synthetic owner authorization refusal')
            context = Path(argv[argv.index('-c') + 1])
            raw = struct.pack('>IIIIQH', 0xbadcc0de, 1, 0x40000001, 0x80000000, 1, 3) + b'abc'
            if self.failure == 'persistent-context':
                raw = struct.pack('>IIIIQH', 0xbadcc0de, 1, 0x40000001, HANDLE, 1, 3) + b'abc'
            self.output(context, raw)
            public = ecc_public()
            if self.failure == 'wrong-public':
                public = bytearray(public)
                public[2:4] = b'\x00\x01'
                public = bytes(public)
            self.created[str(context)] = public
            self.output(Path(argv[argv.index('-o') + 1]), public)
            if self.failure == 'kill-after-create':
                os.kill(os.getpid(), signal.SIGKILL)
            return 'synthetic primary observation'
        if tool == 'tpm2_evictcontrol':
            context = argv[argv.index('-c') + 1]
            # Persistent input would evict the input object, irrespective of destination.
            if context.startswith('0x'):
                self.persistent.pop(int(context, 16), None)
                self.mutations.append('unexpected-eviction')
                return 'evicted'
            assert Path(context).is_file() and context in self.created
            handle = int(argv[-1], 16)
            if self.failure == 'collision':
                self.persistent[handle] = b'synthetic concurrent occupant'
            if handle in self.persistent:
                raise RuntimeError('synthetic occupied destination refusal')
            self.mutations.append('persist')
            self.persistent[handle] = self.created[context]
            if self.failure == 'existing-drift':
                self.persistent[DEFAULT] = b'synthetic unexpected existing-object change'
            if self.failure == 'nv-drift':
                self.nv[0x01800001] = 'synthetic unexpected NV metadata change'
            if self.failure == 'after-persist':
                raise RuntimeError('synthetic uncertain persistence outcome')
            if self.failure == 'kill-after-persist':
                os.kill(os.getpid(), signal.SIGKILL)
            return 'persisted'
        raise AssertionError('unexpected TPM command')


class ParentMaintenanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name)
        self.state.chmod(0o700)
        self.live = snapshot()
        entry = self.live['boot']['entry']
        self.live['manifest']['images'][entry].update(
            sha256=self.live['boot']['sha256'], pcr_key_fingerprint='b' * 64)
        self.config = {'keys': {'pcr_public': '/fixture-public'}}
        self.run = lambda argv: ''
        self.settings = {'version': 1, 'host': 'dancer',
                         'tpm_device': '/dev/tpmrm0', 'tpm_tools': TOOLS}
        self.tpm = TpmModel(self.state)
        evidence = {'entry_id': entry, **self.live['manifest']['images'][entry]}
        with installer_lock(self.state):
            operation = migration.begin_operation(self.state, 'issuer', {'version': 1})
            for phase in ('prepared', 'exchanged', 'published', 'manual-boot-accepted', 'complete'):
                migration.record_phase(operation, phase, evidence)

    def dependencies(self):
        m = module()
        patches = (
            patch.object(m, 'collect_runtime', side_effect=lambda *args: copy.deepcopy(self.live)),
            patch.object(m, '_bits', return_value=2048),
            patch.object(m, 'load_settings', return_value=self.settings),
            patch.object(m, '_settings_snapshot', return_value={'immutable-settings': 'c' * 64}),
            patch.object(m, '_device_snapshot', return_value={'synthetic-device': 42}, create=True),
            patch.object(m, '_run_tpm', side_effect=self.tpm),
        )
        for value in patches:
            value.start()
            self.addCleanup(value.stop)
        return m

    def arm(self, **changes):
        m = self.dependencies()
        flags = {'manual_unlock_attested': True, 'recovery_backup_attested': True,
                 'firmware_risk_accepted': True, 'trusted_enrollment_attested': True,
                 'hardware_primitives_attested': True, **changes}
        return m.arm_parent(self.state, self.config, self.run,
                            Path(self.live['boot']['closure']), HANDLE, **flags)

    def provision(self):
        m = module()
        function = getattr(tpm_parent, 'provision_parent', None)
        self.assertTrue(callable(function), 'explicit parent controller API missing')
        guard = m.ParentGuard(self.state, self.config, self.run)
        return function(self.state / 'migrations/parent', HANDLE, self.state, self.run, guard=guard)

    def test_actual_hardware_primitives_are_a_separate_required_human_gate(self):
        import inspect
        self.assertIn('hardware_primitives_attested', inspect.signature(module().arm_parent).parameters,
                      'actual hardware primitive HUMAN gate missing; TestParms is insufficient')

    def test_parent_arm_is_separate_permanent_approval_not_issuer_authority(self):
        self.arm()
        path = self.state / 'parent-maintenance.json'
        original = path.read_bytes()
        self.assertEqual(json.loads(original)['scope'], 'human-approved-explicit-ecc-parent-only')
        self.assertFalse((self.state / 'migrations/parent').exists())
        self.assertEqual(self.tpm.mutations, [])
        with self.assertRaises((ValueError, FileExistsError)):
            self.arm()
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_missing_attestations_refuse_before_tpm_queries_or_approval(self):
        for key in ('manual_unlock_attested', 'recovery_backup_attested',
                    'firmware_risk_accepted', 'trusted_enrollment_attested', 'hardware_primitives_attested'):
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.arm(**{key: False})
        self.assertEqual(self.tpm.calls, [])
        self.assertFalse((self.state / 'parent-maintenance.json').exists())

    def test_occupied_approved_slot_refuses_without_mutation_or_accepted_context(self):
        self.tpm.persistent[HANDLE] = b'synthetic occupant'
        before = dict(self.tpm.persistent)
        with self.assertRaises(ValueError):
            self.arm()
        self.assertEqual(self.tpm.persistent, before)
        self.assertEqual(self.tpm.mutations, [])
        self.assertFalse((self.state / 'parent-maintenance.json').exists())

    def test_guard_detects_runtime_or_approval_replacement_before_tpm_mutation(self):
        self.arm()
        guard = module().ParentGuard(self.state, self.config, self.run)
        self.live['boot']['sha256'] = 'f' * 64
        with self.assertRaises(ValueError):
            guard.check()
        self.assertEqual(self.tpm.mutations, [])
        path = self.state / 'parent-maintenance.json'
        raw = path.read_bytes()
        path.rename(self.state / 'retained-parent-context.json')
        private_bytes(path, raw)
        with self.assertRaises(ValueError):
            module().ParentGuard(self.state, self.config, self.run)

    def test_loaded_guard_detects_control_binding_file_drift_before_mutation(self):
        self.arm()
        guard = module().ParentGuard(self.state, self.config, self.run)
        private_bytes(self.state / 'parent-maintenance-binding.json', b'{}')
        with self.assertRaises(ValueError):
            guard.check()
        self.assertEqual(self.tpm.mutations, [])

    def test_plain_issuer_context_does_not_authorize_parent(self):
        m = self.dependencies()
        migration._write_once(self.state, 'issuer-maintenance.json', {'version': 1, 'scope': 'human-approved-software-issuer-only'})
        with self.assertRaises(ValueError):
            m.ParentGuard(self.state, self.config, self.run)
        self.assertEqual(self.tpm.calls, [])

    def test_controller_persists_only_created_ecc_and_preserves_existing_objects_nv_header(self):
        self.arm()
        default = self.tpm.persistent[DEFAULT]
        nv = dict(self.tpm.nv)
        header = copy.deepcopy(self.live['invariants']['header'])
        receipt = self.provision()
        self.assertTrue(receipt.is_file())
        operation = migration.read_operation(self.state / 'migrations/parent')
        self.assertEqual(operation['phase'], 'complete')
        self.assertEqual(self.tpm.persistent[HANDLE], ecc_public())
        self.assertEqual(self.tpm.persistent[DEFAULT], default)
        self.assertEqual(self.tpm.nv, nv)
        self.assertEqual(self.live['invariants']['header'], header)
        self.assertEqual(self.tpm.mutations, ['create', 'persist'])
        self.assertFalse(any(call[0] == 'tpm2_flushcontext' for call in self.tpm.calls))

    def test_owner_auth_error_retains_intent_and_refuses_repeat_before_new_transport(self):
        self.arm()
        self.tpm.failure = 'owner-auth'
        with self.assertRaises(RuntimeError):
            self.provision()
        intent = self.state / 'migrations/parent/attempt.json'
        original = intent.read_bytes()
        mutations = list(self.tpm.mutations)
        with self.assertRaises(ValueError):
            self.provision()
        self.assertEqual(intent.read_bytes(), original)
        self.assertEqual(self.tpm.mutations, mutations)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, 'install')

    def test_persistent_context_or_wrong_public_stops_before_persistence(self):
        self.arm()
        self.tpm.failure = 'persistent-context'
        with self.assertRaises(ValueError):
            self.provision()
        self.assertNotIn(HANDLE, self.tpm.persistent)
        self.assertEqual(self.tpm.mutations, ['create'])

    def test_wrong_public_stops_before_persistence(self):
        self.arm()
        self.tpm.failure = 'wrong-public'
        with self.assertRaises(ValueError):
            self.provision()
        self.assertNotIn(HANDLE, self.tpm.persistent)
        self.assertEqual(self.tpm.mutations, ['create'])

    def test_collision_never_evicts_occupant_or_default(self):
        self.arm()
        default = self.tpm.persistent[DEFAULT]
        self.tpm.failure = 'collision'
        with self.assertRaises(RuntimeError):
            self.provision()
        self.assertEqual(self.tpm.persistent[HANDLE], b'synthetic concurrent occupant')
        self.assertEqual(self.tpm.persistent[DEFAULT], default)
        self.assertEqual(self.tpm.mutations, ['create'])
        self.assertEqual(migration.read_operation(self.state / 'migrations/parent')['phase'], 'transient-verified')

    def test_uncertain_persistence_keeps_new_object_and_barrier_without_retry(self):
        self.arm()
        self.tpm.failure = 'after-persist'
        with self.assertRaises(RuntimeError):
            self.provision()
        self.assertEqual(self.tpm.persistent[HANDLE], ecc_public())
        original = (self.state / 'migrations/parent/attempt.json').read_bytes()
        with self.assertRaises(ValueError):
            self.provision()
        self.assertEqual(self.tpm.mutations, ['create', 'persist'])
        self.assertEqual((self.state / 'migrations/parent/attempt.json').read_bytes(), original)
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, 'confirm-boot', self.live['boot']['entry'])

    def test_changed_existing_object_stops_without_deleting_new_or_old_objects(self):
        self.arm()
        self.tpm.failure = 'existing-drift'
        with self.assertRaises(ValueError):
            self.provision()
        self.assertIn(DEFAULT, self.tpm.persistent)
        self.assertIn(HANDLE, self.tpm.persistent)
        self.assertEqual(migration.read_operation(self.state / 'migrations/parent')['phase'], 'transient-verified')

    def test_nv_metadata_drift_stops_without_completing(self):
        self.arm()
        self.tpm.failure = 'nv-drift'
        with self.assertRaises(ValueError):
            self.provision()
        self.assertEqual(migration.read_operation(self.state / 'migrations/parent')['phase'], 'transient-verified')

    def test_completed_provisioning_cannot_be_repeated_or_rebound_to_other_slot(self):
        self.arm()
        self.provision()
        original = (self.state / 'migrations/parent/attempt.json').read_bytes()
        mutations = list(self.tpm.mutations)
        with self.assertRaises(ValueError):
            self.provision()
        self.assertEqual(self.tpm.mutations, mutations)
        self.assertEqual((self.state / 'migrations/parent/attempt.json').read_bytes(), original)

    def test_nonempty_or_unknown_owner_auth_refuses_approval_without_guessing(self):
        self.tpm.owner_auth_set = True
        with self.assertRaises(ValueError):
            self.arm()
        self.assertEqual(self.tpm.mutations, [])
        self.assertFalse((self.state / 'parent-maintenance.json').exists())

    def test_pinned_getcap_empty_owner_format_is_accepted_without_invented_raw_field(self):
        m = module()
        # Verbatim layout from pinned tools5.7 dump_permanent_attrs/prop_str.
        output = 'TPM2_PT_PERMANENT:\n  ownerAuthSet:              0\n  endorsementAuthSet:        0\n'
        try:
            result = m._empty_owner(lambda argv: output)
        except ValueError:
            self.fail('pinned empty-owner output rejected by parser')
        self.assertTrue(result)
        for bad in ('TPM2_PT_PERMANENT:\n', output + '  ownerAuthSet:              1\n',
                    output + output, output.replace('              0', '              1'),
                    output.replace('ownerAuthSet:', 'unknownOwnerAuth:')):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                m._empty_owner(lambda argv: bad)

    def test_pinned_unpadded_nv_handles_are_canonicalized_with_strict_class_and_duplicates(self):
        m = module()
        try:
            values = m._handles('- 0x1800001\n', 0x01)  # Pinned dump_handles uses %X.
        except ValueError:
            self.fail('pinned unpadded NV handle rejected')
        self.assertEqual(values, [0x01800001])
        for bad in ('- 0x81000001\n', '- 0x1800001\n- 0x01800001\n',
                    '- 0x100000001\n', '- 0x1\n', 'unrecognized'):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                m._handles(bad, 0x01)

    def test_native_tool_umask_cannot_make_new_outputs_group_accessible(self):
        self.tpm.tool_group_mode = True  # Pinned tpm2_tool main calls umask(0117).
        try:
            self.arm()
            self.provision()
        except ValueError:
            self.fail('native group-mode output was not pre-created privately')
        artifacts = self.state / 'migrations/parent/artifacts'
        for path in artifacts.rglob('*'):
            self.assertEqual(path.stat().st_mode & 0o777, 0o700 if path.is_dir() else 0o600)

    def test_tpm_runner_uses_clean_environment_and_sanitized_error(self):
        m = module()
        argv = ['tpm2_getcap', '-T', 'device:/dev/tpmrm0', 'handles-persistent']
        with patch.dict(os.environ, {'TPM2TOOLS_TCTI': 'untrusted', 'LD_PRELOAD': 'untrusted'}), \
                patch.object(m, 'TPM_TOOLS', TOOLS), \
                patch.object(m.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, b'', b'')) as native:
            m._run_tpm(self.settings, argv)
            self.assertEqual(native.call_args.kwargs['env'], {'LC_ALL': 'C', 'LANG': 'C', 'PATH': TOOLS})
            self.assertEqual(native.call_args.args[0][0], TOOLS + '/tpm2_getcap')
        with patch.object(m, 'TPM_TOOLS', TOOLS), \
                patch.object(m.subprocess, 'run', side_effect=subprocess.CalledProcessError(9, [], stderr=b'synthetic protected identifier')):
            with self.assertRaises(RuntimeError) as error:
                m._run_tpm(self.settings, argv)
            self.assertNotIn('protected identifier', str(error.exception))
        with self.assertRaises(ValueError):
            m._run_tpm(self.settings, ['tpm2_clear', '-T', 'device:/dev/tpmrm0', '-C', 'p'])

    def test_non_dancer_loader_refuses_before_configuration_or_transport(self):
        m = module()
        with patch.object(m, 'hostname', return_value='kellanved'), \
                patch.object(m, '_run_tpm', side_effect=AssertionError('transport too early')):
            with self.assertRaises(ValueError):
                m.load_settings()

    def test_missing_parent_attestations_and_live_3072_cannot_become_authority(self):
        self.dependencies()
        with patch.object(module(), '_bits', return_value=3072), self.assertRaises(ValueError):
            module().arm_parent(self.state, self.config, self.run, Path(self.live['boot']['closure']), HANDLE,
                    manual_unlock_attested=True, recovery_backup_attested=True,
                    firmware_risk_accepted=True, trusted_enrollment_attested=True,
                    hardware_primitives_attested=True)
        self.assertEqual(self.tpm.calls, [])

    def test_actual_sigkill_after_create_retains_intent_and_barrier(self):
        self.arm()
        self.tpm.failure = 'kill-after-create'
        pid = os.fork()
        if pid == 0:
            try:
                self.provision()
            except BaseException:
                os._exit(4)
            os._exit(0)
        _, status = os.waitpid(pid, 0)
        self.assertTrue(os.WIFSIGNALED(status))
        self.assertEqual(os.WTERMSIG(status), signal.SIGKILL)
        current = migration.read_operation(self.state / 'migrations/parent')
        self.assertEqual(current['phase'], 'intent')
        with self.assertRaises(ValueError):
            self.provision()
        self.assertEqual(self.tpm.mutations, [])  # Child's model is not shared hardware.
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, 'install')

    def test_actual_sigkill_after_persist_retains_verified_transient_barrier(self):
        self.arm()
        self.tpm.failure = 'kill-after-persist'
        pid = os.fork()
        if pid == 0:
            try:
                self.provision()
            except BaseException:
                os._exit(4)
            os._exit(0)
        _, status = os.waitpid(pid, 0)
        self.assertTrue(os.WIFSIGNALED(status))
        self.assertEqual(os.WTERMSIG(status), signal.SIGKILL)
        current = migration.read_operation(self.state / 'migrations/parent')
        self.assertEqual(current['phase'], 'transient-verified')
        with self.assertRaises(ValueError):
            self.provision()
        with self.assertRaises(ValueError):
            migration.require_writer_allowed(self.state, 'install')

    def test_settings_refuse_other_hosts_device_or_tool_directory(self):
        m = module()
        with patch.object(m, 'TPM_TOOLS', TOOLS):
            self.assertEqual(m.validate_settings(self.settings), self.settings)
            for change in ({'host': 'kellanved'}, {'tpm_device': '/dev/tpm0'},
                           {'tpm_tools': '/usr/bin'}, {'version': True}, {'force': True}):
                with self.subTest(change=change), self.assertRaises(ValueError):
                    m.validate_settings({**self.settings, **change})


if __name__ == '__main__':
    unittest.main()
