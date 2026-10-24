"""Enrollment metadata/command boundary; synthetic data only, no TPM transport.

Breaks caught: accepting a no-op/partial write, recovery-slot/digest drift, wrong
PCR policy/issuer/serialized parent, or caller-controlled credentials/settings.
"""
import base64
import copy
import hashlib
import importlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import unittest
from unittest.mock import patch

from test_tpm_parent import ecc_public


def api(name):
    try:
        module = importlib.import_module('secure_uki.tpm_enrollment')
    except ModuleNotFoundError as error:
        if error.name != 'secure_uki.tpm_enrollment':
            raise
        raise AssertionError('missing enrollment boundary API') from None
    value = getattr(module, name, None)
    assert callable(value), 'missing enrollment boundary API'
    return value


def b64(value):
    return base64.b64encode(value).decode('ascii')


# Pinned ESYS serialized resource: handle, sized SHA256 Name, key-resource id1,
# sized TPM2B_PUBLIC. Name independently follows the TCG publicArea digest rule.
PUBLIC = ecc_public()
ISSUER = b'-----BEGIN PUBLIC KEY-----\nSYNTHETIC-ONLY\n-----END PUBLIC KEY-----\n'
NAME = b'\x00\x0b' + hashlib.sha256(PUBLIC[2:]).digest()
SRK = struct.pack('>IH', 0x81000042, 34) + NAME + struct.pack('>I', 1) + PUBLIC
TOKEN = {
    'type': 'systemd-tpm2', 'keyslots': ['1'], 'tpm2-blob': b64(b'synthetic-sealed-blob'),
    'tpm2-pcrs': [7, 12], 'tpm2-pcr-bank': 'sha256', 'tpm2-primary-alg': 'ecc',
    'tpm2-policy-hash': 'a' * 64, 'tpm2_pubkey_pcrs': [11],
    'tpm2_pubkey': b64(ISSUER), 'tpm2_srk': b64(SRK),
}


def headers():
    before = {
        'keyslots': {'0': {
            'type': 'luks2', 'key_size': 64,
            'af': {'type': 'luks1', 'stripes': 4000, 'hash': 'sha256'},
            'area': {'type': 'raw', 'offset': '32768', 'size': '258048',
                     'encryption': 'aes-xts-plain64', 'key_size': 64},
            'kdf': {'type': 'argon2id', 'time': 4, 'memory': 65536, 'cpus': 1,
                    'salt': b64(b'r' * 32)},
        }},
        'tokens': {},
        'digests': {'0': {'type': 'pbkdf2', 'keyslots': ['0'], 'segments': ['0'],
                         'hash': 'sha256', 'iterations': 12345,
                         'salt': b64(b'd' * 32), 'digest': b64(b'h' * 32)}},
        'segments': {'0': {'type': 'crypt', 'offset': '16777216', 'size': 'dynamic',
                           'iv_tweak': '0', 'encryption': 'aes-xts-plain64', 'sector_size': 512}},
        'config': {'json_size': '12288', 'keyslots_size': '16744448'},
    }
    after = copy.deepcopy(before)
    after['keyslots']['1'] = {
        'type': 'luks2', 'key_size': 64,
        # Pinned native minimal-PBKDF SHA512 also selects the NEW slot AF hash.
        # Recovery AF SHA256 remains byte-for-byte unchanged.
        'af': {'type': 'luks1', 'stripes': 4000, 'hash': 'sha512'},
        'area': {'type': 'raw', 'offset': '290816', 'size': '258048',
                 'encryption': 'aes-xts-plain64', 'key_size': 64},
        'kdf': {'type': 'pbkdf2', 'hash': 'sha512', 'iterations': 1000,
                'salt': b64(b's' * 32)},
    }
    after['tokens']['0'] = copy.deepcopy(TOKEN)
    after['digests']['0']['keyslots'].append('1')
    return before, after


class EnrollmentDeltaTests(unittest.TestCase):
    def check(self, before, after, **changes):
        options = {'handle': 0x81000042, 'parent_public': PUBLIC, 'issuer_public': ISSUER}
        options.update(changes)
        return api('verify_enrollment_delta')(before, after, **options)

    def accepted(self, before, after):
        try:
            return self.check(before, after)
        except ValueError:
            self.fail('exact pinned native slot/token delta refused')

    def test_accepts_exact_slot_token_and_digest_delta_without_mutating_inputs(self):
        before, after = headers()
        frozen = copy.deepcopy((before, after))
        self.assertEqual(self.accepted(before, after), {'keyslot': '1', 'token': '0'})
        self.assertEqual((before, after), frozen)

    def test_refuses_noop_slot_only_token_only_and_extra_slots_or_tokens(self):
        verify = api('verify_enrollment_delta')
        before, after = headers()
        for case in ('noop', 'slot-only', 'token-only', 'extra-slot', 'extra-token'):
            bad = copy.deepcopy(after)
            if case == 'noop': bad = copy.deepcopy(before)
            elif case == 'slot-only': bad['tokens'] = {}
            elif case == 'token-only': bad['keyslots'] = copy.deepcopy(before['keyslots'])
            elif case == 'extra-slot': bad['keyslots']['2'] = copy.deepcopy(bad['keyslots']['1'])
            else: bad['tokens']['1'] = copy.deepcopy(bad['tokens']['0'])
            with self.subTest(case=case), self.assertRaises(ValueError):
                verify(before, bad, handle=0x81000042, parent_public=PUBLIC, issuer_public=ISSUER)

    def test_refuses_any_recovery_config_segment_or_digest_parameter_drift(self):
        api('verify_enrollment_delta')
        for target, field, value in (
                ('recovery', 'key_size', 32), ('config', 'json_size', '24576'),
                ('segment', 'sector_size', 4096), ('digest', 'iterations', 1)):
            before, after = headers()
            node = {'recovery': after['keyslots']['0'], 'config': after['config'],
                    'segment': after['segments']['0'], 'digest': after['digests']['0']}[target]
            node[field] = value
            with self.subTest(target=target), self.assertRaises(ValueError): self.check(before, after)

    def test_refuses_wrong_missing_duplicate_or_extra_digest_associations(self):
        api('verify_enrollment_delta')
        for refs in (['0'], ['1'], ['0', '1', '1'], ['0', '1', '2']):
            before, after = headers()
            after['digests']['0']['keyslots'] = refs
            with self.subTest(refs=refs), self.assertRaises(ValueError): self.check(before, after)
        before, after = headers()
        after['digests']['1'] = copy.deepcopy(after['digests']['0'])
        with self.assertRaises(ValueError): self.check(before, after)

    def test_refuses_wrong_policy_fields_and_unknown_pin_pcrlock_or_salt(self):
        api('verify_enrollment_delta')
        for field, value in (
                ('type', 'external'), ('keyslots', ['0']), ('tpm2-pcrs', [7]),
                ('tpm2-pcrs', [7, 11, 12]), ('tpm2-pcr-bank', 'sha1'),
                ('tpm2-primary-alg', 'rsa'), ('tpm2_pubkey_pcrs', []),
                ('tpm2_pubkey_pcrs', [11, 12]), ('tpm2_pubkey_pcrs', [True]),
                ('tpm2_pubkey', b64(b'other issuer')), ('tpm2-pin', False),
                ('tpm2_pcrlock', True), ('tpm2_salt', b64(b'salt')),
                ('unknown-field', 'unknown')):
            before, after = headers()
            after['tokens']['0'][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError): self.check(before, after)

    def test_refuses_missing_token_fields_and_bad_shard_encodings(self):
        api('verify_enrollment_delta')
        for field in TOKEN:
            before, after = headers()
            del after['tokens']['0'][field]
            with self.subTest(field=field), self.assertRaises(ValueError): self.check(before, after)
        for field, value in (('tpm2-policy-hash', ''), ('tpm2-policy-hash', ['a' * 64]),
                             ('tpm2-policy-hash', 'A' * 64), ('tpm2-blob', ''),
                             ('tpm2-blob', '!!!!'), ('tpm2-blob', [b64(b'blob')]),
                             ('tpm2_pubkey', b64(ISSUER) + '\n')):
            before, after = headers()
            after['tokens']['0'][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError): self.check(before, after)

    def test_refuses_wrong_selector_name_public_resource_type_or_trailing_bytes(self):
        api('verify_enrollment_delta')
        for raw in (struct.pack('>I', 0x81000001) + SRK[4:],
                    SRK[:6] + b'\x00\x0b' + b'wrong-name' * 4 + SRK[40:],
                    SRK[:40] + struct.pack('>I', 2) + SRK[44:],
                    SRK[:-1], SRK + b'\0'):
            before, after = headers()
            after['tokens']['0']['tpm2_srk'] = b64(raw)
            with self.subTest(raw_size=len(raw)), self.assertRaises(ValueError): self.check(before, after)
        before, after = headers()
        # Other valid P256 point: opposite generator y, same eligibility/template.
        prime = 0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff
        other = PUBLIC[:-32] + (prime - int.from_bytes(PUBLIC[-32:], 'big')).to_bytes(32, 'big')
        with self.assertRaises(ValueError): self.check(before, after, parent_public=other)

    def test_new_slot_af_must_match_native_sha512_not_recovery_hash(self):
        api('verify_enrollment_delta')
        before, after = headers()
        self.assertEqual(self.accepted(before, after), {'keyslot': '1', 'token': '0'})
        for field, value in (('hash', 'sha256'), ('hash', 'sha1'), ('stripes', 1), ('type', 'other')):
            bad = copy.deepcopy(after)
            bad['keyslots']['1']['af'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError): self.check(before, bad)

    def test_refuses_new_slot_kdf_weakening_area_overlap_or_cipher_change(self):
        api('verify_enrollment_delta')
        for part, field, value in (
                ('kdf', 'type', 'argon2id'), ('kdf', 'hash', 'sha1'),
                ('kdf', 'iterations', 1), ('kdf', 'iterations', True),
                ('area', 'offset', '32768'), ('area', 'size', '0'),
                ('area', 'offset', '999999999'), ('area', 'encryption', 'aes-cbc-plain')):
            before, after = headers()
            after['keyslots']['1'][part][field] = value
            with self.subTest(part=part, field=field), self.assertRaises(ValueError): self.check(before, after)

    def test_refuses_json_numeric_type_drift_in_original_metadata_or_pcr_masks(self):
        api('verify_enrollment_delta')
        for target in ('recovery', 'literal', 'signed'):
            before, after = headers()
            if target == 'recovery': after['keyslots']['0']['key_size'] = 64.0
            elif target == 'literal': after['tokens']['0']['tpm2-pcrs'] = [7.0, 12]
            else: after['tokens']['0']['tpm2_pubkey_pcrs'] = [11.0]
            with self.subTest(target=target), self.assertRaises(ValueError): self.check(before, after)

    def test_refuses_json_numeric_type_drift_in_new_slot_af_and_area(self):
        api('verify_enrollment_delta')
        for part, field, value in (('af', 'stripes', 4000.0), ('area', 'key_size', 64.0)):
            before, after = headers()
            after['keyslots']['1'][part][field] = value
            with self.subTest(part=part), self.assertRaises(ValueError): self.check(before, after)

    def test_malformed_nested_json_fails_closed_with_value_error(self):
        api('verify_enrollment_delta')
        for target in ('config', 'digests', 'recovery', 'area', 'references'):
            before, after = headers()
            if target == 'config': before['config'] = after['config'] = None
            elif target == 'digests': before['digests']['0'] = None
            elif target == 'recovery': before['keyslots']['0'] = None
            elif target == 'area': after['keyslots']['1']['area'] = None
            else: after['digests']['0']['keyslots'] = [{'unhashable': 1}]
            with self.subTest(target=target), self.assertRaises(ValueError): self.check(before, after)

    def test_refuses_preexisting_tokens_and_noncanonical_indices(self):
        api('verify_enrollment_delta')
        before, after = headers()
        before['tokens']['0'] = copy.deepcopy(TOKEN)
        with self.assertRaises(ValueError): self.check(before, after)
        for group in ('keyslots', 'tokens', 'digests'):
            before, after = headers()
            key = next(iter(after[group]))
            after[group]['0' + key] = after[group].pop(key)
            with self.subTest(group=group), self.assertRaises(ValueError): self.check(before, after)


class EnrollmentContractTests(unittest.TestCase):
    def test_command_fixes_measurements_device_and_no_pin_or_pcrlock(self):
        command = api('enrollment_arguments')(0x81000042)
        self.assertEqual(command, [
            '/dev/nvme0n1p2', '--tpm2-device=/dev/tpmrm0',
            '--tpm2-seal-key-handle=0x81000042', '--tpm2-pcrs=7:sha256+12:sha256',
            '--tpm2-public-key-pcrs=11',
            '--tpm2-public-key=/var/lib/secure-uki/pcr-signing/public.pem',
            '--tpm2-signature=/var/lib/secure-uki/migrations/enrollment/artifacts/userspace-signature.json',
            '--tpm2-with-pin=no', '--tpm2-pcrlock=',
        ])

    def test_default_transient_platform_bool_and_unselected_handles_refused(self):
        builder = api('enrollment_arguments')
        for handle in (0, 0x81000001, 0x80000000, 0x81800000, True, '0x81000042'):
            with self.subTest(handle=handle), self.assertRaises(ValueError): builder(handle)

    def test_native_child_cannot_inherit_password_credentials_loader_or_config(self):
        environment = api('terminal_environment')
        with patch.dict(os.environ, {'PASSWORD': 'synthetic-do-not-transfer',
                'CREDENTIALS_DIRECTORY': '/hostile-creds', 'LD_PRELOAD': '/hostile-loader',
                'OPENSSL_CONF': '/hostile-config', 'TPM2TOOLS_TCTI': 'hostile',
                'SYSTEMD_ASK_PASSWORD_KEYRING_TYPE': 'user', 'SYSTEMD_LOG_LEVEL': 'debug'}):
            observed = subprocess.run([sys.executable, '-I', '-B', '-c',
                'import json,os; print(json.dumps(dict(os.environ)))'],
                env=environment(), check=True, text=True, capture_output=True)
        values = json.loads(observed.stdout)
        for key in ('PASSWORD', 'NEWPASSWORD', 'CREDENTIALS_DIRECTORY', 'LD_PRELOAD',
                    'OPENSSL_CONF', 'TPM2TOOLS_TCTI'):
            self.assertNotIn(key, values)
        self.assertEqual(values['SYSTEMD_ASK_PASSWORD_KEYRING_TYPE'], 'process')
        self.assertEqual(values['SYSTEMD_ASK_PASSWORD_KEYRING_TIMEOUT_SEC'], '0')
        self.assertEqual(values['SYSTEMD_LOG_LEVEL'], 'info')
        self.assertEqual(values['SYSTEMD_LOG_TARGET'], 'console')
        self.assertNotIn('synthetic-do-not-transfer', observed.stdout + observed.stderr)
        self.assertIsNot(environment(), environment())


if __name__ == '__main__':
    unittest.main()
