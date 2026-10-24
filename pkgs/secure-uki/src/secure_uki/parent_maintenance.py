"""Separate opt-in HUMAN parent approval, never issuer or enrollment authority.

The administrator/OS and enrollment window are trusted. These checks detect
ordinary drift, not privileged concurrent replacement or firmware compromise.
TPM identities/diagnostics stay in protected encrypted state. No default parent,
hierarchy-auth input, slot search, eviction, clearing or recovery/replay API.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess

from . import migration_state as migration
from .maintenance import _confirmed, collect_runtime, hostname
from .policy_rotation import _bits, _read_file
from .publish import installer_lock
from .tpm_parent import create_private_output, read_private_blob, validate_parent_handle

TPM_TOOLS = None  # Compiled by the package; never caller PATH/config/environment.
SETTINGS = Path('/etc/secure-uki-parent-maintenance.json')
CONTEXT = 'parent-maintenance.json'
SCOPE = 'human-approved-explicit-ecc-parent-only'
TPM_COMMANDS = {'tpm2_getcap', 'tpm2_readpublic', 'tpm2_nvreadpublic',
                'tpm2_createprimary', 'tpm2_evictcontrol'}
DEVICE = 'device:/dev/tpmrm0'


def validate_settings(value):
    if (not isinstance(value, dict)
            or set(value) != {'version', 'host', 'tpm_device', 'tpm_tools'}
            or type(value['version']) is not int or value['version'] != 1
            or value['host'] != 'dancer' or value['tpm_device'] != '/dev/tpmrm0'
            or TPM_TOOLS is None or value['tpm_tools'] != TPM_TOOLS):
        raise ValueError('parent maintenance requires fixed opt-in Dancer TPM settings')
    return value


def load_settings():
    # Host/default-off checks precede any state/key/TPM access.
    if hostname() != 'dancer':
        raise ValueError('parent maintenance requires Dancer')
    path = SETTINGS.resolve(strict=True)
    info = path.stat()
    if (not path.is_relative_to('/nix/store') or not stat.S_ISREG(info.st_mode)
            or info.st_uid != 0 or info.st_mode & 0o022):
        raise ValueError('parent maintenance requires immutable Nix configuration')
    value = validate_settings(json.loads(path.read_text(), object_pairs_hook=migration._unique))
    for name in TPM_COMMANDS:
        tool = Path(value['tpm_tools']) / name
        resolved = tool.resolve(strict=True)
        info = resolved.stat()
        if (not resolved.is_relative_to('/nix/store') or not stat.S_ISREG(info.st_mode)
                or info.st_uid != 0 or info.st_mode & 0o022 or not os.access(tool, os.X_OK)):
            raise ValueError('parent maintenance requires immutable pinned TPM tools')
    return value


def _settings_snapshot(closure):
    path = SETTINGS.resolve(strict=True)
    if path != (closure / 'etc' / SETTINGS.name).resolve(strict=True):
        raise ValueError('parent settings differ from actual booted source')
    return _read_file(path)


def _run_tpm(settings, argv):
    # No shell or inherited environment (including TCTI/provider/loader overrides).
    if (not isinstance(argv, list) or len(argv) < 4 or argv[0] not in TPM_COMMANDS
            or argv[1:3] != ['-T', DEVICE] or not all(isinstance(x, str) for x in argv)):
        raise ValueError('unsupported fixed TPM command')
    validate_settings(settings)
    executable = str(Path(settings['tpm_tools']) / argv[0])
    try:
        result = subprocess.run([executable, *argv[1:]], check=True, capture_output=True,
                                env={'LC_ALL': 'C', 'LANG': 'C', 'PATH': settings['tpm_tools']},
                                timeout=120)
    except subprocess.TimeoutExpired:
        raise RuntimeError('pinned TPM command timed out; outcome uncertain, no retry') from None
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f'{argv[0]} failed (exit {exc.returncode}); no retry') from None
    if len(result.stdout) > 65536 or len(result.stderr) > 65536:
        raise ValueError('oversized protected TPM diagnostic')
    try:
        return result.stdout.decode('ascii')
    except UnicodeError:
        raise ValueError('invalid protected TPM diagnostic') from None


def _handles(output, prefix):
    if not isinstance(output, str) or len(output) > 8192:
        raise ValueError('invalid protected TPM handle inventory')
    result = []
    for line in output.splitlines():
        # Pinned dump_handles uses %X, so NV indices need not be zero-padded.
        match = re.fullmatch(r'- 0x([0-9a-fA-F]{1,8})', line)
        if not match:
            raise ValueError('unexpected protected TPM handle inventory')
        handle = int(match[1], 16)
        if handle >> 24 != prefix or handle in result:
            raise ValueError('invalid protected TPM handle class or duplicate')
        result.append(handle)
    if len(result) > 32:
        raise ValueError('protected TPM inventory exceeds bound')
    return sorted(result)


def _device_snapshot():
    path = Path('/dev/tpmrm0')
    info = path.lstat()
    if (not stat.S_ISCHR(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o007
            or path.resolve(strict=True) != path):
        raise ValueError('fixed protected TPM resource-manager device required')
    return {'inode': info.st_ino, 'device': info.st_dev, 'rdev': info.st_rdev,
            'mode': stat.S_IMODE(info.st_mode), 'uid': info.st_uid, 'gid': info.st_gid}


def _empty_owner(command):
    output = command(['tpm2_getcap', '-T', DEVICE, 'properties-variable'])
    sections = re.findall(r'(?m)^TPM2_PT_PERMANENT:\n((?:[ \t].*(?:\n|$))*)', output)
    if len(sections) != 1:
        raise ValueError('owner authorization state unavailable; no guessing')
    # Pinned5.7 dump_permanent_attrs prints padded booleans, NOT a raw field.
    # Require one explicit reported-empty owner flag; absent/ambiguous/1 STOP.
    flag = re.findall(r'(?m)^  ownerAuthSet: +([01])$', sections[0])
    if flag != ['0']:
        raise ValueError('owner authorization is nonempty or unknown; no guessing/change')
    return True


def inventory(directory, command):
    """Read-only inventory into a fresh protected directory; returns private data."""
    directory.mkdir(mode=0o700)
    migration._directory(directory)
    _empty_owner(command)
    persistent = _handles(command(['tpm2_getcap', '-T', DEVICE, 'handles-persistent']), 0x81)
    nv = _handles(command(['tpm2_getcap', '-T', DEVICE, 'handles-nv-index']), 0x01)
    objects = {}
    for handle in persistent:
        path = directory / f'{handle:08x}.public'
        create_private_output(path)
        command(['tpm2_readpublic', '-T', DEVICE, '-c', f'0x{handle:08x}', '-f', 'tss', '-o', str(path)])
        raw, _ = read_private_blob(path, limit=2048)
        objects[f'0x{handle:08x}'] = raw.hex()
    nv_public = {}
    for handle in nv:
        raw = command(['tpm2_nvreadpublic', '-T', DEVICE, f'0x{handle:08x}'])
        nv_public[f'0x{handle:08x}'] = hashlib.sha256(raw.encode('ascii')).hexdigest()
    if (persistent != _handles(command(['tpm2_getcap', '-T', DEVICE, 'handles-persistent']), 0x81)
            or nv != _handles(command(['tpm2_getcap', '-T', DEVICE, 'handles-nv-index']), 0x01)):
        raise ValueError('TPM inventory changed during read')
    migration._sync_directory(directory)
    _empty_owner(command)
    return {'persistent': objects, 'nv': nv_public, 'owner_auth_empty': True}


def _runtime(state, config, run):
    if (state / 'journal.json').exists() or (state / 'journal.json').is_symlink():
        raise ValueError('parent maintenance refuses pending publication')
    live = collect_runtime(config, run)  # Issuer's empty-token guard stays unchanged.
    _confirmed(live)
    entry = live['boot']['entry']
    if (live['manifest']['default'] != entry or live['manifest']['known_good'] != entry
            or live['boot']['pcr_public_sha256'] != live['issuer']['files']['public.pem']['sha256']
            or _bits(Path(config['keys']['pcr_public']), run) != 2048):
        raise ValueError('parent approval requires exact confirmed software RSA2048 manual boot')
    operations = migration._operations(state)
    issuer = next((x for x in operations if x['kind'] == 'issuer'), None)
    if (issuer is None or issuer['phase'] != 'complete'
            or any(x['kind'] not in {'issuer', 'parent'} for x in operations)):
        raise ValueError('parent approval requires completed issuer migration and no enrollment')
    candidate = migration._candidate(issuer['receipts'][-1]['evidence'])
    actual = {'entry_id': entry, 'closure': live['boot']['closure'], 'sha256': live['boot']['sha256'],
              'pcr_key_fingerprint': live['manifest']['images'][entry]['pcr_key_fingerprint']}
    if candidate != migration._candidate(actual):
        raise ValueError('confirmed boot differs from accepted issuer candidate')
    return {'live': live, 'device': _device_snapshot(),
            'settings': _settings_snapshot(Path(live['boot']['closure'])),
            'code': _read_file(Path(__file__).resolve()),
            'issuer_receipt': _read_file(state / 'migrations/issuer/0005-complete.json', 0o600)}


def arm_parent(state, config, run, approved_closure, handle, *, manual_unlock_attested,
               recovery_backup_attested, firmware_risk_accepted, trusted_enrollment_attested,
               hardware_primitives_attested):
    if not all(value is True for value in (manual_unlock_attested, recovery_backup_attested,
                                          firmware_risk_accepted, trusted_enrollment_attested,
                                          hardware_primitives_attested)):
        raise ValueError('separate HUMAN manual recovery/backup/firmware risk/trusted-window/actual-primitives approval required')
    validate_parent_handle(handle)
    settings = load_settings()
    with installer_lock(state):
        migration.require_writer_allowed(state, 'install')
        before = _runtime(state, config, run)
        if str(approved_closure) != before['live']['boot']['closure']:
            raise ValueError('parent approval requires the exact approved booted closure')
        attempt = migration._write_once(state, 'parent-approval-attempt.json',
                {'version': 1, 'scope': SCOPE, 'handle': handle, 'before': before})
        artifacts = state / 'parent-approval-artifacts'
        artifacts.mkdir(mode=0o700)
        migration._sync_directory(state)
        observed = inventory(artifacts / 'first', lambda argv: _run_tpm(settings, argv))
        if f'0x{handle:08x}' in observed['persistent']:
            raise ValueError('approved parent slot is occupied; no overwrite or slot search')
        if (observed != inventory(artifacts / 'second', lambda argv: _run_tpm(settings, argv))
                or _runtime(state, config, run) != before or load_settings() != settings):
            raise ValueError('parent approval baseline drifted')
        context = migration._write_once(state, CONTEXT,
                {'version': 1, 'scope': SCOPE, 'handle': handle, 'state_binding': migration._binding(state),
                 'before': before, 'inventory': observed, 'attempt': _read_file(attempt, 0o600)})
        migration._write_once(state, 'parent-maintenance-binding.json',
                {'version': 1, 'context': _read_file(context, 0o600)})
        return context


class ParentGuard:
    def __init__(self, state, config, run):
        self.state, self.config, self.run = state, config, run
        self.settings = load_settings()
        self.path = state / CONTEXT
        if not self.path.exists() or self.path.is_symlink():
            raise ValueError('separate permanent HUMAN parent approval required')
        self.identity = _read_file(self.path, 0o600)
        self.binding_identity = _read_file(state / 'parent-maintenance-binding.json', 0o600)
        binding, _ = migration._read(state / 'parent-maintenance-binding.json')
        self.context, _ = migration._read(self.path)
        if (binding != {'version': 1, 'context': self.identity}
                or type(binding.get('version')) is not int
                or set(self.context) != {'version', 'scope', 'handle', 'state_binding', 'before', 'inventory', 'attempt'}
                or type(self.context['version']) is not int or self.context['version'] != 1
                or self.context['scope'] != SCOPE
                or self.context['state_binding'] != migration._binding(state)
                or self.context['attempt'] != _read_file(state / 'parent-approval-attempt.json', 0o600)):
            raise ValueError('invalid separate permanent HUMAN parent approval')
        validate_parent_handle(self.context['handle'])
        attempt, _ = migration._read(state / 'parent-approval-attempt.json')
        if attempt != {'version': 1, 'scope': SCOPE, 'handle': self.context['handle'], 'before': self.context['before']}:
            raise ValueError('parent approval attempt differs')

    def check(self):
        if (_read_file(self.path, 0o600) != self.identity
                or _read_file(self.state / 'parent-maintenance-binding.json', 0o600) != self.binding_identity
                or self.context['state_binding'] != migration._binding(self.state)
                or self.context['attempt'] != _read_file(self.state / 'parent-approval-attempt.json', 0o600)
                or load_settings() != self.settings
                or _runtime(self.state, self.config, self.run) != self.context['before']):
            raise ValueError('approved parent runtime/context/source/header/trust drift')
        return {'context': self.identity, 'handle': self.context['handle']}

    def command(self, argv):
        if _device_snapshot() != self.context['before']['device']:
            raise ValueError('approved TPM resource-manager device changed')
        return _run_tpm(self.settings, argv)


def dispatch(args, config, run):
    load_settings()
    state = Path(config['state_dir'])
    if args.command == 'parent-arm':
        return arm_parent(state, config, run, args.closure, args.handle,
                manual_unlock_attested=args.manual_unlock_attested,
                recovery_backup_attested=args.recovery_backup_attested,
                firmware_risk_accepted=args.firmware_risk_accepted,
                trusted_enrollment_attested=args.trusted_enrollment_attested,
                hardware_primitives_attested=args.hardware_primitives_attested)
    if args.command == 'parent-provision':
        from .tpm_parent import provision_parent
        guard = ParentGuard(state, config, run)
        return provision_parent(state / 'migrations/parent', guard.context['handle'], state, run, guard=guard)
    raise ValueError('unsupported explicit parent command')
