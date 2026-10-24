"""Separate enrollment authority + real ledger/file effects; injected live transport.

Mutations caught: issuer/parent scope reuse, missing approvals/prior receipts,
wrong parent/header/runtime, replay and premature confirmation/enrollment completion.
Native terminal interaction is tested separately; this module models that boundary.
"""
import copy
import hashlib
import importlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from secure_uki import migration_state as migration, parent_maintenance as parent, tpm_enrollment as enrollment, tpm_parent
from secure_uki.publish import installer_lock
from test_maintenance import snapshot
from test_parent_maintenance import TpmModel, TOOLS
from test_tpm_enrollment import headers, PUBLIC, ISSUER

SYSTEMD = '/nix/store/' + 'c' * 32 + '-systemd-260.4'


def api():
    try:
        return importlib.import_module('secure_uki.enrollment_maintenance')
    except ModuleNotFoundError as error:
        if error.name != 'secure_uki.enrollment_maintenance': raise
        raise AssertionError('separate enrollment approval/controller API missing') from None


class EnrollmentMaintenanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name)
        self.state.chmod(0o700)
        self.live = snapshot()
        self.live['invariants']['header'] = headers()[0]
        self.public = self.state / 'public.pem'
        self.public.write_bytes(ISSUER)
        self.public.chmod(0o644)
        digest = hashlib.sha256(ISSUER).hexdigest()
        self.live['boot']['pcr_public_sha256'] = digest
        self.live['issuer']['files']['public.pem']['sha256'] = digest
        entry = self.live['boot']['entry']
        self.live['manifest']['images'][entry].update(sha256=self.live['boot']['sha256'], pcr_key_fingerprint='b' * 64)
        self.candidate = {'entry_id': entry, **self.live['manifest']['images'][entry]}
        self.config = {'keys': {'pcr_public': str(self.public)}, 'state_dir': str(self.state)}
        self.run = lambda argv: ''
        self.settings = {'version': 1, 'host': 'dancer', 'tpm_device': '/dev/tpmrm0', 'tpm_tools': TOOLS}
        self.model = TpmModel(self.state)
        for patcher in (
                patch.object(parent, 'collect_runtime', side_effect=lambda *args: copy.deepcopy(self.live)),
                patch.object(parent, '_bits', return_value=2048),
                patch.object(parent, 'load_settings', return_value=self.settings),
                patch.object(parent, '_settings_snapshot', return_value={'fixture-settings': 'c' * 64}),
                patch.object(parent, '_device_snapshot', return_value={'fixture-device': 42}),
                patch.object(parent, '_run_tpm', side_effect=self.model)):
            patcher.start(); self.addCleanup(patcher.stop)
        with installer_lock(self.state):
            op = migration.begin_operation(self.state, 'issuer', {'version': 1})
            for phase in ('prepared', 'exchanged', 'published', 'manual-boot-accepted', 'complete'):
                migration.record_phase(op, phase, self.candidate)
        parent.arm_parent(self.state, self.config, self.run, Path(self.live['boot']['closure']), 0x81000042,
                         manual_unlock_attested=True, recovery_backup_attested=True,
                         firmware_risk_accepted=True, trusted_enrollment_attested=True,
                         hardware_primitives_attested=True)
        guard = parent.ParentGuard(self.state, self.config, self.run)
        tpm_parent.provision_parent(self.state / 'migrations/parent', 0x81000042, self.state, self.run, guard=guard)

    def dependencies(self):
        module = api()
        def live(config, run, *, header_guard):
            observed = copy.deepcopy(self.live)
            header_guard(observed['invariants']['header'])
            return observed
        for patcher in (
                patch.object(module, '_collect_runtime', side_effect=live),
                patch.object(module, '_bits', return_value=2048),
                patch.object(module, 'load_settings', return_value={'version': 1, 'host': 'dancer', 'systemd': SYSTEMD}),
                patch.object(module, '_settings_snapshot', return_value={'fixture-enrollment-settings': 'f' * 64})):
            patcher.start(); self.addCleanup(patcher.stop)
        return module

    def arm(self, **changes):
        flags = dict(manual_unlock_attested=True, recovery_backup_attested=True,
                     signing_backup_attested=True, firmware_risk_accepted=True,
                     trusted_enrollment_attested=True, hardware_primitives_attested=True,
                     approve_rsa2048=True)
        flags.update(changes)
        return api().arm_enrollment(self.state, self.config, self.run, Path(self.live['boot']['closure']), **flags)

    def test_separate_permanent_approval_no_enrollment_or_native_mutation(self):
        self.dependencies(); self.arm()
        path = self.state / 'enrollment-maintenance.json'
        original = path.read_bytes()
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertFalse((self.state / 'migrations/enrollment').exists())
        with self.assertRaises((ValueError, FileExistsError)): self.arm()
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual(self.live['invariants']['header'], headers()[0])

    def test_every_missing_human_gate_refuses_before_any_enrollment_approval(self):
        self.dependencies()
        for flag in ('manual_unlock_attested', 'recovery_backup_attested', 'signing_backup_attested',
                     'firmware_risk_accepted', 'trusted_enrollment_attested', 'hardware_primitives_attested', 'approve_rsa2048'):
            with self.subTest(flag=flag), self.assertRaises(ValueError): self.arm(**{flag: False})
        self.assertFalse((self.state / 'enrollment-approval-attempt.json').exists())

    def test_issuer_and_parent_approval_do_not_authorize_enrollment(self):
        module = self.dependencies()
        with self.assertRaises(ValueError): module.EnrollmentGuard(self.state, self.config, self.run)
        self.assertFalse((self.state / 'migrations/enrollment').exists())

    def test_wrong_closure_unconfirmed_boot_wrong_issuer_bits_or_preexisting_token_refuse(self):
        module = self.dependencies()
        for key in ('confirmation', 'issuer', 'tokens'):
            old = copy.deepcopy(self.live)
            if key == 'confirmation': self.live['confirmation']['SubState'] = 'running'
            elif key == 'issuer': self.live['boot']['pcr_public_sha256'] = 'f' * 64
            else: self.live['invariants']['header'] = headers()[1]
            with self.subTest(key=key), self.assertRaises(ValueError): self.arm()
            self.live = old
        with patch.object(module, '_bits', return_value=3072), self.assertRaises(ValueError): self.arm()
        flags = dict(manual_unlock_attested=True, recovery_backup_attested=True, signing_backup_attested=True,
                     firmware_risk_accepted=True, trusted_enrollment_attested=True,
                     hardware_primitives_attested=True, approve_rsa2048=True)
        with self.assertRaises(ValueError):
            module.arm_enrollment(self.state, self.config, self.run, Path('/wrong'), **flags)
        self.assertFalse((self.state / 'enrollment-maintenance.json').exists())

    def test_missing_approved_parent_refuses_approval(self):
        self.dependencies()
        self.model.persistent.pop(0x81000042)
        with self.assertRaises(ValueError): self.arm()
        self.assertFalse((self.state / 'enrollment-maintenance.json').exists())

    def test_changed_approved_parent_refuses_approval(self):
        self.dependencies()
        self.model.persistent[0x81000042] = b'RSA instead of approved ECC'
        with self.assertRaises(ValueError): self.arm()
        self.assertFalse((self.state / 'enrollment-maintenance.json').exists())

    def test_guard_refuses_context_binding_replacement_and_runtime_drift(self):
        module = self.dependencies(); self.arm()
        guard = module.EnrollmentGuard(self.state, self.config, self.run)
        for field in ('boot', 'issuer', 'manifest', 'invariants'):
            old = copy.deepcopy(self.live)
            self.live[field]['unexpected'] = 'drift'
            with self.subTest(field=field), self.assertRaises(ValueError): guard.check('before')
            self.live = old
        path = self.state / 'enrollment-maintenance-binding.json'
        original = path.read_bytes()
        path.rename(self.state / 'retained-enrollment-binding.json')
        path.write_bytes(original); path.chmod(0o600)
        with self.assertRaises(ValueError): guard.check('before')

    def test_before_guard_rejects_numeric_type_header_drift(self):
        module = self.dependencies(); self.arm()
        guard = module.EnrollmentGuard(self.state, self.config, self.run)
        self.live['invariants']['header']['keyslots']['0']['key_size'] = 64.0
        with self.assertRaises(ValueError): guard.check('before')

    def test_foreign_scope_cannot_be_loaded_as_enrollment_authority(self):
        module = self.dependencies(); self.arm()
        import json
        path = self.state / 'enrollment-maintenance.json'
        data = json.loads(path.read_text())
        data['scope'] = 'human-approved-software-issuer-only'
        path.write_text(json.dumps(data))
        with self.assertRaises(ValueError): module.EnrollmentGuard(self.state, self.config, self.run)

    def native(self, artifacts):
        current = migration.read_operation(self.state / 'migrations/enrollment')
        assert current['phase'] == 'intent'
        assert (self.state / 'migrations/enrollment/attempt.json').stat().st_mode & 0o777 == 0o600
        assert artifacts.is_dir()
        self.live['invariants']['header'] = headers()[1]
        return {'native_exit': 0}

    def test_one_shot_controller_records_verified_candidate_but_not_attended_completion(self):
        module = self.dependencies(); self.arm()
        guard = module.EnrollmentGuard(self.state, self.config, self.run)
        with patch.object(module.EnrollmentGuard, 'invoke', side_effect=self.native):
            receipt = enrollment.enroll_once(self.state / 'migrations/enrollment', self.state, self.run, guard=guard)
        self.assertTrue(receipt.is_file())
        current = migration.read_operation(self.state / 'migrations/enrollment')
        self.assertEqual(current['phase'], 'token-verified')
        self.assertEqual(migration._candidate(current['receipts'][-1]['evidence']), migration._candidate(self.candidate))
        before = (self.state / 'migrations/enrollment/attempt.json').read_bytes()
        with self.assertRaises(ValueError):
            enrollment.enroll_once(self.state / 'migrations/enrollment', self.state, self.run, guard=guard)
        self.assertEqual((self.state / 'migrations/enrollment/attempt.json').read_bytes(), before)
        self.assertEqual(self.live['invariants']['header'], headers()[1])
        with self.assertRaises(ValueError): migration.require_writer_allowed(self.state, 'install')
        migration.require_writer_allowed(self.state, 'confirm-boot', self.live['boot']['entry'])

    def test_native_uncertainty_partial_write_and_noop_leave_intent_no_retry_or_restore(self):
        module = self.dependencies(); self.arm()
        guard = module.EnrollmentGuard(self.state, self.config, self.run)
        def partial(artifacts):
            self.native(artifacts)
            self.live['invariants']['header']['tokens'] = {}
            raise RuntimeError('uncertain native result')
        with patch.object(module.EnrollmentGuard, 'invoke', side_effect=partial):
            with self.assertRaises(RuntimeError):
                enrollment.enroll_once(self.state / 'migrations/enrollment', self.state, self.run, guard=guard)
        current = migration.read_operation(self.state / 'migrations/enrollment')
        self.assertEqual(current['phase'], 'intent')
        self.assertEqual(len(self.live['invariants']['header']['keyslots']), 2)
        with self.assertRaises(ValueError): migration.require_writer_allowed(self.state, 'confirm-boot', self.live['boot']['entry'])
        with self.assertRaises(ValueError):
            enrollment.enroll_once(self.state / 'migrations/enrollment', self.state, self.run, guard=guard)

    def test_noop_success_never_marks_token_written(self):
        module = self.dependencies(); self.arm()
        guard = module.EnrollmentGuard(self.state, self.config, self.run)
        with patch.object(module.EnrollmentGuard, 'invoke', return_value={'native_exit': 0}), self.assertRaises(ValueError):
            enrollment.enroll_once(self.state / 'migrations/enrollment', self.state, self.run, guard=guard)
        self.assertEqual(migration.read_operation(self.state / 'migrations/enrollment')['phase'], 'intent')

    def test_cli_consumes_separate_flags_and_writes_real_enrollment_receipts(self):
        module = self.dependencies()
        from secure_uki import cli
        flags = ['--manual-unlock-attested', '--recovery-backup-attested', '--signing-backup-attested',
                 '--firmware-risk-accepted', '--trusted-enrollment-attested',
                 '--hardware-primitives-attested', '--approve-rsa2048']
        # Only CLI's root check is simulated; shared os.geteuid must retain the
        # real fixture owner for protected state/FD checks. Never weaken those.
        with patch.object(cli, 'os', wraps=os) as cli_os, \
                patch.object(cli, 'load_config', return_value=self.config), patch.object(cli, '_runner', return_value=self.run):
            cli_os.geteuid.return_value = 0
            cli_os.umask.return_value = None
            try:
                cli.main(['enrollment-arm', self.live['boot']['closure'], *flags])
                with patch.object(module.EnrollmentGuard, 'invoke', side_effect=self.native):
                    cli.main(['enrollment-enroll'])
            except SystemExit as error:
                self.fail('separate enrollment CLI unavailable: ' + str(error))
        self.assertEqual(migration.read_operation(self.state / 'migrations/enrollment')['phase'], 'token-verified')

    def test_enrollment_setting_host_gate_precedes_state_access(self):
        module = api()
        with patch.object(module, 'hostname', return_value='kellanved'), self.assertRaises(ValueError):
            module.load_settings()
        with patch.object(module, 'SYSTEMD', SYSTEMD):
            self.assertEqual(module.validate_settings({'version': 1, 'host': 'dancer', 'systemd': SYSTEMD})['host'], 'dancer')
            for changed in ({'version': True}, {'host': 'kellanved'}, {'systemd': '/usr'}, {'force': True}):
                with self.assertRaises(ValueError):
                    module.validate_settings({'version': 1, 'host': 'dancer', 'systemd': SYSTEMD, **changed})

    def verified(self):
        module = self.dependencies(); self.arm()
        guard = module.EnrollmentGuard(self.state, self.config, self.run)
        with patch.object(module.EnrollmentGuard, 'invoke', side_effect=self.native):
            enrollment.enroll_once(self.state / 'migrations/enrollment', self.state, self.run, guard=guard)
        return module, guard

    def accept(self, module, **changes):
        function = getattr(module, 'accept_enrollment', None)
        self.assertTrue(callable(function), 'guarded attended acceptance API missing')
        flags = dict(electrical_cold_attested=True, automatic_unlock_attested=True, manual_recovery_attested=True)
        flags.update(changes)
        return function(self.state, self.config, self.run, **flags)

    def new_boot(self):
        self.live['boot']['boot_id'] = 'synthetic-after-enrollment'

    def test_new_boot_confirmation_allows_running_unit_without_completing_enrollment(self):
        module, guard = self.verified(); self.new_boot()
        self.live['confirmation']['SubState'] = 'running'
        try:
            binding = guard.check('confirm')
        except ValueError as error:
            self.fail('verified exact-candidate normal confirmation refused: ' + str(error))
        self.assertEqual(binding['candidate']['entry_id'], self.candidate['entry_id'])
        self.assertEqual(migration.read_operation(self.state / 'migrations/enrollment')['phase'], 'token-verified')
        with self.assertRaises(ValueError): guard.check('accepted')

    def test_attended_acceptance_requires_different_boot_and_each_explicit_human_attestation(self):
        module, guard = self.verified()
        self.assertTrue(callable(getattr(module, 'accept_enrollment', None)), 'guarded attended acceptance API missing')
        with self.assertRaises(ValueError): self.accept(module)
        self.new_boot()
        for flag in ('electrical_cold_attested', 'automatic_unlock_attested', 'manual_recovery_attested'):
            for invalid in (False, 1):
                with self.subTest(flag=flag, invalid=invalid), self.assertRaises(ValueError): self.accept(module, **{flag: invalid})
        self.assertFalse((self.state / 'migrations/enrollment/artifacts/attended-acceptance-attempt.json').exists())

    def test_acceptance_requires_real_exited_success_zero_confirmation(self):
        module, guard = self.verified(); self.new_boot()
        self.assertTrue(callable(getattr(module, 'accept_enrollment', None)), 'guarded attended acceptance API missing')
        for field, value in (('ActiveState', 'inactive'), ('SubState', 'running'), ('Result', 'failed'), ('ExecMainStatus', '1')):
            original = self.live['confirmation'][field]
            self.live['confirmation'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError): self.accept(module)
            self.live['confirmation'][field] = original
        self.assertEqual(migration.read_operation(self.state / 'migrations/enrollment')['phase'], 'token-verified')

    def test_attended_acceptance_records_bound_receipts_releases_writers_but_never_replays(self):
        module, guard = self.verified(); self.new_boot()
        operation = self.state / 'migrations/enrollment'
        original = (operation / 'attempt.json').read_bytes()
        receipt = self.accept(module)
        self.assertEqual(receipt.name, '0004-complete.json')
        current = migration.read_operation(operation)
        self.assertEqual(current['phase'], 'complete')
        self.assertEqual(current['receipts'][2]['evidence']['boot_id'], 'synthetic-after-enrollment')
        self.assertEqual(current['receipts'][2]['evidence']['entry_id'], self.candidate['entry_id'])
        for action in ('install', 'cleanup', 'confirm-boot'): migration.require_writer_allowed(self.state, action)
        with self.assertRaises(ValueError): self.accept(module)
        self.assertEqual((operation / 'attempt.json').read_bytes(), original)
        self.assertEqual(self.live['invariants']['header'], headers()[1])

    def test_acceptance_attempt_drift_after_attended_receipt_refuses_completion(self):
        module, guard = self.verified(); self.new_boot()
        original = migration.record_phase
        def drift(operation, phase, evidence):
            result = original(operation, phase, evidence)
            if phase == 'attended-boot-accepted':
                (operation / 'artifacts/attended-acceptance-attempt.json').write_text('{"version":1,"wrong":"changed"}')
            return result
        with patch.object(migration, 'record_phase', side_effect=drift), self.assertRaises(ValueError): self.accept(module)
        self.assertEqual(migration.read_operation(self.state / 'migrations/enrollment')['phase'], 'attended-boot-accepted')
        with self.assertRaises(ValueError): migration.require_writer_allowed(self.state, 'install')

    def test_actual_sigkill_after_attended_receipt_retains_one_shot_barrier(self):
        import signal
        module, guard = self.verified(); self.new_boot()
        original = migration.record_phase
        def interrupted(operation, phase, evidence):
            result = original(operation, phase, evidence)
            if phase == 'attended-boot-accepted': os.kill(os.getpid(), signal.SIGKILL)
            return result
        pid = os.fork()
        if pid == 0:
            with patch.object(migration, 'record_phase', side_effect=interrupted): self.accept(module)
            os._exit(90)
        _, status = os.waitpid(pid, 0)
        self.assertTrue(os.WIFSIGNALED(status))
        self.assertEqual(os.WTERMSIG(status), signal.SIGKILL)
        self.assertEqual(migration.read_operation(self.state / 'migrations/enrollment')['phase'], 'attended-boot-accepted')
        with self.assertRaises(ValueError): self.accept(module)
        with self.assertRaises(ValueError): migration.require_writer_allowed(self.state, 'confirm-boot', self.candidate['entry_id'])

    def test_cli_attended_acceptance_consumes_human_flags_and_actual_bound_ledger(self):
        module, guard = self.verified(); self.new_boot()
        from secure_uki import cli
        with patch.object(cli, 'os', wraps=os) as cli_os, \
                patch.object(cli, 'load_config', return_value=self.config), patch.object(cli, '_runner', return_value=self.run):
            cli_os.geteuid.return_value = 0
            cli_os.umask.return_value = None
            try:
                cli.main(['enrollment-accept', '--electrical-cold-attested', '--automatic-unlock-attested', '--manual-recovery-attested'])
            except SystemExit as error:
                self.fail('guarded attended CLI missing: ' + str(error))
        self.assertEqual(migration.read_operation(self.state / 'migrations/enrollment')['phase'], 'complete')

    def test_cli_confirmation_selects_enrollment_guard_not_completed_issuer_authority(self):
        module, guard = self.verified(); self.new_boot()
        from secure_uki import cli
        factory = getattr(cli, '_confirmation_guard', None)
        self.assertTrue(callable(factory), 'phase-aware CLI confirmation guard missing')
        selected = factory(self.state, self.config, self.run)
        self.assertTrue(callable(selected), 'verified enrollment confirmation must not be unguarded')
        self.live['confirmation']['SubState'] = 'running'
        selected('confirm')
        self.live['invariants']['trust']['PK'] = 'wrong-live-trust'
        with self.assertRaises(ValueError): selected('confirm')

    def test_postboot_guard_preserves_source_parent_header_and_all_nonboot_invariants(self):
        module, guard = self.verified(); self.new_boot()
        for field in ('issuer', 'invariants', 'manifest', 'boot'):
            original = copy.deepcopy(self.live)
            self.live[field]['unexpected'] = 'drift'
            with self.subTest(field=field), self.assertRaises(ValueError): guard.check('confirm')
            self.live = original
        self.model.persistent[0x81000042] = b'changed expected parent'
        with self.assertRaises(ValueError): guard.check('confirm')

    def test_postboot_only_devtmpfs_inode_device_numbers_can_change(self):
        module = self.dependencies()
        device = dict(inode=100, device=20, rdev=42, mode=0o660, uid=0, gid=59)
        with patch.object(parent, '_device_snapshot', side_effect=lambda: device.copy()):
            self.arm()
            guard = module.EnrollmentGuard(self.state, self.config, self.run)
            with patch.object(module.EnrollmentGuard, 'invoke', side_effect=self.native):
                enrollment.enroll_once(self.state / 'migrations/enrollment', self.state, self.run, guard=guard)
            self.new_boot(); device.update(inode=101, device=21)
            try: guard.check('confirm')
            except ValueError as error: self.fail('legitimate postboot devtmpfs identity refused: ' + str(error))
            for field in ('rdev', 'mode', 'uid', 'gid'):
                old = device[field]; device[field] += 1
                with self.subTest(field=field), self.assertRaises(ValueError): guard.check('confirm')
                device[field] = old

    def test_interrupted_attended_acceptance_keeps_barrier_and_blocks_replay(self):
        module, guard = self.verified(); self.new_boot()
        self.assertTrue(callable(getattr(module, 'accept_enrollment', None)), 'guarded attended acceptance API missing')
        original = migration.record_phase
        def interrupt(operation, phase, evidence):
            result = original(operation, phase, evidence)
            if phase == 'attended-boot-accepted': raise RuntimeError('interrupted after attended receipt')
            return result
        with patch.object(migration, 'record_phase', side_effect=interrupt), self.assertRaises(RuntimeError): self.accept(module)
        self.assertEqual(migration.read_operation(self.state / 'migrations/enrollment')['phase'], 'attended-boot-accepted')
        with self.assertRaises(ValueError): self.accept(module)
        with self.assertRaises(ValueError): migration.require_writer_allowed(self.state, 'install')
        with self.assertRaises(ValueError): guard.check('confirm')

    def test_native_parent_or_runtime_drift_after_write_blocks_verification(self):
        module = self.dependencies(); self.arm()
        guard = module.EnrollmentGuard(self.state, self.config, self.run)
        def native_drift(artifacts):
            result = self.native(artifacts)
            self.model.persistent[0x81000001] = b'changed original RSA'
            return result
        with patch.object(module.EnrollmentGuard, 'invoke', side_effect=native_drift), self.assertRaises(ValueError):
            enrollment.enroll_once(self.state / 'migrations/enrollment', self.state, self.run, guard=guard)
        self.assertEqual(migration.read_operation(self.state / 'migrations/enrollment')['phase'], 'intent')
        self.assertEqual(self.live['invariants']['header'], headers()[1])


class HeaderCollectionBoundaryTests(unittest.TestCase):
    def test_public_issuer_collector_always_enforces_empty_tokens_at_shared_header_gate(self):
        from secure_uki import maintenance
        self.assertTrue(callable(getattr(maintenance, '_collect_runtime', None)), 'missing internal header-gated collector')
        def transport(config, run, *, header_guard):
            header_guard(headers()[1])
            return {'unexpected': 'must not reach issuer caller'}
        with patch.object(maintenance, '_collect_runtime', side_effect=transport), self.assertRaises(ValueError):
            maintenance.collect_runtime({}, None)
        def unenrolled(config, run, *, header_guard):
            header_guard(headers()[0])
            return {'valid': 'read-only snapshot'}
        with patch.object(maintenance, '_collect_runtime', side_effect=unenrolled):
            self.assertEqual(maintenance.collect_runtime({}, None), {'valid': 'read-only snapshot'})


if __name__ == '__main__': unittest.main()
