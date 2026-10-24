"""Maintenance coordination: real protected receipts, injected read-only observations."""
import copy
import hashlib
import json
import os
import stat
import importlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from secure_uki import migration_state as migration
from secure_uki.publish import installer_lock


def api():
    if importlib.util.find_spec('secure_uki.maintenance') is None:
        raise AssertionError('guarded issuer maintenance API missing')
    return importlib.import_module('secure_uki.maintenance')


def snapshot():
    closure='/nix/store/'+'a'*32+'-maintenance'
    entry='dancer-'+'b'*64+'.efi'
    return {'invariants':{'closure':closure,'source':{'immutable-code':'a'*64},
                          'trust':{'PK':'b'*64},'header':{'tokens':{}},'mounts':{'encrypted':True},
                          'history':{'witness':'c'*64}},
            'boot':{'closure':closure,'entry':entry,'sha256':'b'*64,'boot_id':'synthetic-before','pcr_public_sha256':'e'*64},
            'issuer':{'directory':{'inode':42},'files':{'private.pem':{'sha256':'d'*64},'public.pem':{'sha256':'e'*64}}},
            'confirmation':{'ActiveState':'active','SubState':'exited','Result':'success','ExecMainStatus':'0'},
            'manifest':{'default':entry,'known_good':entry,'images':{entry:{'closure':closure}}}}


class MaintenanceTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.state=Path(self.temp.name); self.state.chmod(0o700)
        self.observed=snapshot()
        self.cfg={'keys':{'pcr_public':'/fixture-public'}}
        bits=patch.object(api(),'_bits',return_value=3072); bits.start(); self.addCleanup(bits.stop)

    def arm(self, **changes):
        module=api()
        flags={'manual_unlock_attested':True,'recovery_backup_attested':True,'approve_rsa2048':True,**changes}
        with patch.object(module,'collect_runtime',side_effect=lambda *args: copy.deepcopy(self.observed)):
            return module.arm_runtime(self.state, self.cfg, None, Path(self.observed['boot']['closure']), **flags)

    def test_explicit_human_gate_writes_one_fsynced_bound_receipt_not_keys_or_intent(self):
        self.arm()
        context=self.state/'issuer-maintenance.json'; original=context.read_bytes()
        self.assertFalse((self.state/'migrations').exists())
        with self.assertRaises((ValueError, FileExistsError)): self.arm()
        self.assertEqual(context.read_bytes(),original)
        self.assertEqual(context.stat().st_mode & 0o777,0o600)

    def test_each_missing_attestation_and_wrong_approved_closure_refuses_before_receipt(self):
        module=api()
        for key in ('manual_unlock_attested','recovery_backup_attested','approve_rsa2048'):
            with self.subTest(key=key), self.assertRaises(ValueError): self.arm(**{key:False})
        self.assertFalse((self.state/'issuer-maintenance.json').exists())
        with patch.object(module,'collect_runtime',return_value=self.observed):
            with self.assertRaises(ValueError):
                module.arm_runtime(self.state,self.cfg,None,Path('/nix/store/'+'e'*32+'-wrong'),
                                   manual_unlock_attested=True,recovery_backup_attested=True,approve_rsa2048=True)
        self.assertFalse((self.state/'issuer-maintenance.json').exists())

    def test_arm_detects_final_read_drift_before_permanent_receipt(self):
        module=api(); changed=copy.deepcopy(self.observed); changed['invariants']['header']['tokens']={'unexpected':{}}
        with patch.object(module,'collect_runtime',side_effect=[self.observed,changed]):
            with self.assertRaises(ValueError):
                module.arm_runtime(self.state,self.cfg,None,Path(self.observed['boot']['closure']),
                                   manual_unlock_attested=True,recovery_backup_attested=True,approve_rsa2048=True)
        self.assertFalse((self.state/'issuer-maintenance.json').exists())

    def test_guard_binds_runtime_trust_header_mount_source_history_issuer_and_manifest(self):
        self.arm(); module=api()
        for field in ('invariants','boot','issuer','manifest'):
            with self.subTest(field=field):
                altered=copy.deepcopy(self.observed); altered[field]['unexpected']='drift'
                with patch.object(module,'collect_runtime',return_value=altered):
                    with self.assertRaises(ValueError): module.RuntimeGuard(self.state,{},None)('prepare')
        with patch.object(module,'collect_runtime',return_value=self.observed):
            binding=module.RuntimeGuard(self.state,{},None)('prepare')
            self.assertEqual(binding['closure'],self.observed['boot']['closure'])
            self.assertFalse((self.state/'migrations').exists())

    def test_guard_rejects_same_bytes_context_replacement_and_foreign_intent(self):
        self.arm(); module=api(); guard=module.RuntimeGuard(self.state,{},None)
        context=self.state/'issuer-maintenance.json'; raw=context.read_bytes()
        context.rename(self.state/'retained-context.json'); context.write_bytes(raw); context.chmod(0o600)
        with patch.object(module,'collect_runtime',return_value=self.observed):
            with self.assertRaises(ValueError): guard('prepare')
            with self.assertRaises(ValueError): module.RuntimeGuard(self.state,{},None)

    def test_loaded_image_policy_public_key_mismatch_cannot_be_armed(self):
        self.observed['boot']['pcr_public_sha256']='f'*64
        with self.assertRaises(ValueError): self.arm()
        self.assertFalse((self.state/'issuer-maintenance.json').exists())

    def test_pending_journal_refuses_arm_before_accepting_human_flags(self):
        self.state.joinpath('journal.json').write_text('{}')
        with self.assertRaises(ValueError): self.arm()
        self.assertFalse((self.state/'issuer-maintenance.json').exists())

    def test_production_collection_rejects_non_dancer_before_keys_or_tools(self):
        module=api()
        with patch.object(module,'hostname',return_value='kellanved'):
            with self.assertRaises(ValueError): module.collect_runtime({},None)

    def test_plain_config_and_unpinned_tools_cannot_enable_commands(self):
        module=api()
        good={'version':1,'host':'dancer','luks_device':'/dev/nvme0n1p2','esp_device':'/dev/nvme0n1p1',
              'lsattr':'/nix/store/'+'a'*32+'-e2fsprogs/bin/lsattr'}
        self.assertEqual(module.validate_settings(good),good)
        for change in ({'host':'kellanved'},{'version':True},{'lsattr':'/usr/bin/lsattr'},
                       {'luks_device':'/dev/vda2'},{'esp_device':'/dev/vda1'},{'force':True}):
            with self.assertRaises(ValueError): module.validate_settings({**good,**change})


class AuthorityMetadataTests(unittest.TestCase):
    """Real disposable history/files; only fixed production paths are redirected."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.state = self.root / 'state'
        self.state.mkdir(mode=0o700)
        self.sbctl = self.root / 'sbctl'
        self.sbctl.mkdir(mode=0o700)
        (self.sbctl / 'keys').mkdir(mode=0o700)
        self.report = self.state / 'enforcement.vmfix000'
        self.report.mkdir(mode=0o700)
        evidence = self.report / 'evidence'
        evidence.mkdir(mode=0o700)
        self.trust = {}
        self.certificates = []
        for name in api().VARIABLES:
            data = ('synthetic variable ' + name).encode()
            self.save(evidence / (name + '.efivar'), data)
            self.trust[name] = {'sha256': hashlib.sha256(data).hexdigest()}
        for name in ('PK', 'KEK', 'db'):
            directory = self.sbctl / 'keys' / name
            directory.mkdir(mode=0o700)
            data = ('synthetic certificate ' + name).encode()
            certificate = directory / (name + '.pem')
            self.save(certificate, data, 0o644)
            self.save(evidence / ('owner-' + name + '.pem'), data)
            self.certificates.append(certificate)
        self.guid = self.sbctl / 'GUID'
        self.save(self.guid, b'synthetic-owner-identity-only', 0o644)
        self.save(evidence / 'owner-guid.txt', b'synthetic-owner-identity-only')
        accepted = json.dumps({'stage': 'after-enable', 'secure_boot': 1,
                               'anchor': 'fixture', 'boot_id': 'fixture-history'}).encode()
        self.save(self.report / 'accepted.json', accepted)
        witness = {'report': str(self.report / 'accepted.json'),
                   'report_sha256': hashlib.sha256(accepted).hexdigest(),
                   'anchor': 'fixture', 'boot_id': 'fixture-history'}
        self.save(self.state / 'enforcement-first-boot.json', json.dumps(witness).encode())
        self.save(self.state / 'enrollment-attempt.json', b'{"fixture":true}')

    @staticmethod
    def save(path, data, mode=0o600):
        path.write_bytes(data)
        path.chmod(mode)

    def history(self):
        def redirected(value):
            path = Path(value)
            base = Path('/var/lib/sbctl')
            return self.sbctl / path.relative_to(base) if path.is_relative_to(base) else path
        with patch.object(api(), 'Path', side_effect=redirected):
            return api()._history(self.state, self.trust)

    def accepted_history(self):
        try:
            return self.history()
        except ValueError as error:
            self.fail('legitimate sbctl authority metadata rejected: ' + str(error))

    def test_original_sbctl_certificate_and_guid_modes_are_accepted_without_changes(self):
        # Break caught: forcing certificates/GUID0644 or repairing their permissions.
        for certificate_mode, guid_mode in ((0o400, 0o644), (0o644, 0o600),
                                            (0o400, 0o600), (0o644, 0o644)):
            with self.subTest(certificate_mode=certificate_mode, guid_mode=guid_mode):
                for path in self.certificates:
                    path.chmod(certificate_mode)
                self.guid.chmod(guid_mode)
                paths = [*self.certificates, self.guid]
                before = [(path.read_bytes(), path.stat()) for path in paths]
                result = self.accepted_history()
                self.assertEqual(result['owner-PK'], hashlib.sha256(b'synthetic certificate PK').hexdigest())
                self.assertEqual(before, [(path.read_bytes(), path.stat()) for path in paths])

    def test_same_guid_bytes_replacement_changes_frozen_history(self):
        # Break caught: returning only the identity hash, losing inode identity.
        before = self.accepted_history()
        self.guid.rename(self.sbctl / 'retained-original-GUID')
        self.save(self.guid, b'synthetic-owner-identity-only', 0o644)
        self.assertNotEqual(self.accepted_history(), before,
                            'same-byte GUID replacement lost from frozen history')

    def test_each_accepted_guid_mode_is_frozen_not_normalized(self):
        # Break caught: accepting both modes but discarding the actual observed mode.
        before = self.accepted_history()
        self.guid.chmod(0o600)
        self.assertNotEqual(self.accepted_history(), before,
                            'accepted GUID permission drift lost from frozen history')
        self.assertEqual(stat.S_IMODE(self.guid.stat().st_mode), 0o600)

    def test_guid_drift_after_arming_blocks_rotation_before_intent(self):
        # Break caught: the real approval/guard ignores authority metadata drift.
        module = api()
        live = snapshot()
        live['invariants']['history'] = self.accepted_history()
        config = {'keys': {'pcr_public': '/fixture-public'}}
        with patch.object(module, 'collect_runtime', side_effect=lambda *args: copy.deepcopy(live)), \
                patch.object(module, '_bits', return_value=3072):
            module.arm_runtime(self.state, config, None, Path(live['boot']['closure']),
                               manual_unlock_attested=True, recovery_backup_attested=True,
                               approve_rsa2048=True)
            guard = module.RuntimeGuard(self.state, config, None)
            self.guid.chmod(0o600)
            live['invariants']['history'] = self.accepted_history()
            with self.assertRaisesRegex(ValueError, 'runtime/source/mount/trust/header/history drift'):
                guard('prepare')
        self.assertFalse((self.state / 'migrations').exists())

    def test_unapproved_authority_permissions_refuse_without_repair(self):
        # Break caught: dropping mode binding or accepting writable/group-private inputs.
        for path, mode in ((self.certificates[0], 0o600), (self.certificates[0], 0o664),
                           (self.certificates[0], 0o444), (self.guid, 0o400), (self.guid, 0o664)):
            with self.subTest(path=path.name, mode=mode):
                path.chmod(mode)
                with self.assertRaises(ValueError):
                    self.history()
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), mode)
                path.chmod(0o644)

    def test_authority_symlinks_and_hardlinks_remain_refused(self):
        # Break caught: widening the immutable-public-source link exception to state.
        for path in (self.certificates[0], self.guid):
            retained = path.with_name(path.name + '.retained')
            with self.subTest(path=path.name, kind='symlink'):
                path.rename(retained)
                path.symlink_to(retained)
                with self.assertRaises(ValueError):
                    self.history()
                path.unlink()
                retained.rename(path)
            with self.subTest(path=path.name, kind='hardlink'):
                os.link(path, retained)
                with self.assertRaises(ValueError):
                    self.history()
                retained.unlink()

    def test_wrong_authority_owner_remains_refused(self):
        # Break caught: avoiding the owner-bound file reader for public authority data.
        from types import SimpleNamespace
        real_lstat = Path.lstat
        for target in (self.certificates[0], self.guid):
            def changed(path, *args, **kwargs):
                info = real_lstat(path, *args, **kwargs)
                if path != target:
                    return info
                values = {name: getattr(info, name) for name in dir(info) if name.startswith('st_')}
                return SimpleNamespace(**{**values, 'st_uid': os.geteuid() + 1})
            with self.subTest(path=target.name), patch.object(Path, 'lstat', changed):
                with self.assertRaises(ValueError):
                    self.history()


if __name__=='__main__': unittest.main()
