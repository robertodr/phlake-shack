"""Conventional enrollment boundary primitives, NOT a mutation/approval API.

The future separately authorized controller must hold installer_lock, validate
runtime/issuer/parent/backup, persist intent, and use a native human terminal.
Metadata consistency is not unseal/boot acceptance or protection from privileged
concurrent replacement. No native expected-public binding is claimed.
"""
import base64
import binascii
import copy
import hashlib
import json
import re
import struct

from .tpm_parent import validate_parent, validate_parent_handle

PUBLIC_KEY = '/var/lib/secure-uki/pcr-signing/public.pem'
SIGNATURE = '/var/lib/secure-uki/migrations/enrollment/artifacts/userspace-signature.json'


def enrollment_arguments(handle: int) -> list[str]:
    """Fixed native arguments; this does not execute or authorize enrollment."""
    validate_parent_handle(handle)
    return ['/dev/nvme0n1p2', '--tpm2-device=/dev/tpmrm0',
            f'--tpm2-seal-key-handle=0x{handle:08x}',
            '--tpm2-pcrs=7:sha256+12:sha256', '--tpm2-public-key-pcrs=11',
            '--tpm2-public-key=' + PUBLIC_KEY, '--tpm2-signature=' + SIGNATURE,
            '--tpm2-with-pin=no', '--tpm2-pcrlock=']


def terminal_environment() -> dict[str, str]:
    """Fresh allowlist, never inherited PASSWORD/credentials/loader/tool overrides.

    Pinned systemd supports a process-local password keyring. Disable insertion
    timeout as well; do not clear unrelated root/user/session keys. Independent
    manual recovery remains a separate acceptance gate, never inferred from cache.
    Native stderr/stdout/TTY and timeout accounting belong to the future controller.
    """
    return {'LC_ALL': 'C', 'LANG': 'C', 'SYSTEMD_LOG_LEVEL': 'info',
            'SYSTEMD_LOG_TARGET': 'console', 'SYSTEMD_COLORS': '0',
            'SYSTEMD_EMOJI': '0', 'SYSTEMD_ASK_PASSWORD_KEYRING_TYPE': 'process',
            'SYSTEMD_ASK_PASSWORD_KEYRING_TIMEOUT_SEC': '0'}


def _base64(value, maximum: int) -> bytes:
    if type(value) is not str or not 0 < len(value) <= 4 * ((maximum + 2) // 3):
        raise ValueError('invalid enrollment encoding')
    try:
        raw = base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error):
        raise ValueError('invalid enrollment encoding') from None
    if not raw or len(raw) > maximum or base64.b64encode(raw).decode('ascii') != value:
        raise ValueError('invalid enrollment encoding')
    return raw


def _indices(value) -> set[str]:
    if type(value) is not dict or len(value) > 32:
        raise ValueError('invalid enrollment index map')
    for key in value:
        if type(key) is not str or not re.fullmatch(r'0|[1-9][0-9]?', key) or int(key) >= 32:
            raise ValueError('invalid enrollment index')
    return set(value)


def _references(value) -> set[str]:
    if (type(value) is not list or not value or len(value) > 32
            or any(type(item) is not str for item in value)):
        raise ValueError('invalid enrollment digest references')
    result = _indices(dict.fromkeys(value))
    if len(result) != len(value):
        raise ValueError('duplicate enrollment digest references')
    return result


def _serialized_parent(value, handle: int, public: bytes) -> None:
    """Pinned ESYS key resource layout, validated after write, not native binding."""
    raw = _base64(value, 4096)
    name = b'\x00\x0b' + hashlib.sha256(public[2:]).digest()
    expected = struct.pack('>IH', handle, len(name)) + name + struct.pack('>I', 1) + public
    if raw != expected:
        raise ValueError('enrolled parent differs from approved parent')


def _same_metadata(left, right) -> bool:
    try:
        return (json.dumps(left, sort_keys=True, allow_nan=False)
                == json.dumps(right, sort_keys=True, allow_nan=False))
    except (TypeError, ValueError):
        raise ValueError('invalid LUKS metadata encoding') from None


def _new_slot(slot, reference, config) -> None:
    if (type(slot) is not dict or set(slot) != {'type', 'key_size', 'af', 'area', 'kdf'}
            or slot['type'] != 'luks2' or type(slot['key_size']) is not int
            or slot['key_size'] != reference.get('key_size')
            or type(reference.get('af')) is not dict
            or not _same_metadata(slot['af'], {**reference['af'], 'hash': 'sha512'})):
        raise ValueError('unexpected enrollment slot parameters')
    kdf = slot['kdf']
    if (type(kdf) is not dict or set(kdf) != {'type', 'hash', 'iterations', 'salt'}
            or kdf['type'] != 'pbkdf2' or kdf['hash'] != 'sha512'
            or type(kdf['iterations']) is not int or kdf['iterations'] != 1000
            or len(_base64(kdf['salt'], 32)) != 32):
        raise ValueError('unexpected native TPM slot KDF')
    area = slot['area']
    original = reference.get('area', {})
    if (type(area) is not dict or set(area) != set(original)
            or not _same_metadata({k: v for k, v in area.items() if k != 'offset'},
                                  {k: v for k, v in original.items() if k != 'offset'})):
        raise ValueError('unexpected enrollment slot area')
    for value in (area.get('offset'), area.get('size'), config.get('json_size'), config.get('keyslots_size')):
        if type(value) is not str or not re.fullmatch(r'[1-9][0-9]*', value) or len(value) > 12:
            raise ValueError('invalid enrollment slot area')
    start, size = int(area['offset']), int(area['size'])
    lower = 2 * (4096 + int(config['json_size']))
    if start < lower or start % 4096 or size % 4096 or start + size > lower + int(config['keyslots_size']):
        raise ValueError('enrollment slot outside keyslot area')


def verify_enrollment_delta(before: dict, after: dict, *, handle: int,
                            parent_public: bytes, issuer_public: bytes) -> dict[str, str]:
    """Require exactly one native token/slot and its existing-volume digest link.

    Old recovery slots and all other metadata must remain identical. No-op,
    partial/extra/unknown writes STOP; never wipe, retry or restore. Inputs are
    snapshots from the fixed device, not authority. Blob/policy-hash encoding and
    declared PCR/issuer/serialized-parent fields are checked; this does NOT prove
    cryptographic policy execution, decryption or attended acceptance.
    """
    validate_parent_handle(handle)
    validate_parent(parent_public)
    if type(issuer_public) is not bytes or not 0 < len(issuer_public) <= 16384:
        raise ValueError('invalid approved issuer public')
    for header in (before, after):
        if type(header) is not dict or set(header) != {'keyslots', 'tokens', 'digests', 'segments', 'config'}:
            raise ValueError('unexpected LUKS metadata shape')
        for field in ('keyslots', 'tokens', 'digests'):
            _indices(header[field])
            if any(type(value) is not dict for value in header[field].values()):
                raise ValueError('invalid nested LUKS metadata')
        if type(header['config']) is not dict or type(header['segments']) is not dict:
            raise ValueError('invalid nested LUKS metadata')
        for existing in header['keyslots'].values():
            if type(existing.get('area')) is not dict:
                raise ValueError('invalid nested LUKS keyslot area')
    if not before['keyslots'] or before['tokens'] or len(after['tokens']) != 1:
        raise ValueError('unexpected enrollment token delta')
    old_slots, new_slots = set(before['keyslots']), set(after['keyslots'])
    added = new_slots - old_slots
    if len(added) != 1 or not old_slots <= new_slots:
        raise ValueError('unexpected enrollment slot delta')
    slot = added.pop()
    token_id, token = next(iter(after['tokens'].items()))
    fields = {'type', 'keyslots', 'tpm2-blob', 'tpm2-pcrs', 'tpm2-pcr-bank',
              'tpm2-primary-alg', 'tpm2-policy-hash', 'tpm2_pubkey_pcrs', 'tpm2_pubkey', 'tpm2_srk'}
    if (type(token) is not dict or set(token) != fields or token['type'] != 'systemd-tpm2'
            or any(type(token[key]) is not list or any(type(pcr) is not int for pcr in token[key])
                   for key in ('tpm2-pcrs', 'tpm2_pubkey_pcrs'))
            or token['keyslots'] != [slot] or token['tpm2-pcrs'] != [7, 12]
            or token['tpm2_pubkey_pcrs'] != [11] or token['tpm2-pcr-bank'] != 'sha256'
            or token['tpm2-primary-alg'] != 'ecc'):
        raise ValueError('unexpected enrollment policy metadata')
    if (type(token['tpm2-policy-hash']) is not str
            or not re.fullmatch(r'[0-9a-f]{64}', token['tpm2-policy-hash'])
            or token['tpm2-policy-hash'] == '0' * 64):
        raise ValueError('invalid enrollment policy digest')
    _base64(token['tpm2-blob'], 65536)
    if _base64(token['tpm2_pubkey'], 16384) != issuer_public:
        raise ValueError('enrolled policy issuer changed')
    _serialized_parent(token['tpm2_srk'], handle, parent_public)
    normalized = copy.deepcopy(after)
    del normalized['keyslots'][slot]
    normalized['tokens'] = {}
    if set(before['digests']) != set(after['digests']):
        raise ValueError('unexpected enrollment digest delta')
    associated = []
    for index, digest in before['digests'].items():
        refs = _references(digest.get('keyslots'))
        new_refs = _references(after['digests'][index].get('keyslots'))
        if slot in new_refs:
            if new_refs != refs | {slot} or not refs <= old_slots:
                raise ValueError('unexpected enrollment digest association')
            associated.append(index)
            normalized['digests'][index]['keyslots'] = digest['keyslots']
        elif new_refs != refs:
            raise ValueError('existing enrollment digest association changed')
    if len(associated) != 1 or not _same_metadata(normalized, before):
        raise ValueError('unexpected LUKS metadata delta')
    reference_id = before['digests'][associated[0]]['keyslots'][0]
    _new_slot(after['keyslots'][slot], before['keyslots'][reference_id], before['config'])
    area = after['keyslots'][slot]['area']
    start, end = int(area['offset']), int(area['offset']) + int(area['size'])
    for existing in before['keyslots'].values():
        old = existing['area']
        if start < int(old['offset']) + int(old['size']) and int(old['offset']) < end:
            raise ValueError('enrollment area overlaps recovery slot')
    return {'keyslot': slot, 'token': token_id}


def enroll_once(operation, state, run, *, guard):
    """Exactly one separately HUMAN-authorized native attempt; no replay/rollback.

    Ends at token-verified, NOT attended acceptance or completion. Native failures
    or drift retain intent, partial header and all artifacts. Physical approval
    is the owner's responsibility; this API never infers it from root/config.
    """
    from . import migration_state as migration
    from .enrollment_maintenance import EnrollmentGuard
    from .publish import installer_lock
    if (type(guard) is not EnrollmentGuard or guard.state != state or guard.run is not run
            or operation != state / 'migrations/enrollment'):
        raise ValueError('separate exact enrollment approval required')
    with installer_lock(state):
        if operation.exists() or operation.is_symlink():
            raise ValueError('permanent enrollment attempt exists; no replay')
        binding = guard.check('before')
        actual = migration.begin_operation(state, 'enrollment', {'version': 1,
                'approval': binding['approval'], 'candidate': binding['candidate']})
        if actual != operation:
            raise ValueError('enrollment operation path differs')
        artifacts = operation / 'artifacts'
        artifacts.mkdir(mode=0o700)
        migration._sync_directory(operation)
        guard.check('before')
        result = guard.invoke(artifacts)
        if (type(result) is not dict or type(result.get('native_exit')) is not int
                or result['native_exit'] != 0):
            raise ValueError('unexpected native enrollment result; no retry')
        written = guard.check('written')
        evidence = {**binding['candidate'], 'approval': binding['approval'],
                    'header_after': written['header'], 'native': result}
        migration.record_phase(operation, 'token-written', evidence)
        guard.check('verified')
        return migration.record_phase(operation, 'token-verified', evidence)
