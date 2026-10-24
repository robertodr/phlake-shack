"""Separate permanent HUMAN enrollment authority; trusted administrator/window.

No issuer/parent context or JSON setting alone authorizes native LUKS writes.
Ordinary drift STOPs; live checks/locks are not hostile-root race exclusion.
"""
import copy
import hashlib
import json
import os
from pathlib import Path
import stat
import tempfile

from . import migration_state as migration, parent_maintenance as parent
from .maintenance import _collect_runtime, _confirmed, _unenrolled_header, hostname
from .policy_rotation import _bits, _read_file
from .publish import installer_lock
from .tpm_enrollment import _same_metadata, verify_enrollment_delta
from .tpm_parent import validate_parent

SYSTEMD = None  # Compiled immutable native tool binding, never caller configuration.
SETTINGS = Path('/etc/secure-uki-enrollment-maintenance.json')
CONTEXT = 'enrollment-maintenance.json'
SCOPE = 'human-approved-measured-tpm-enrollment-only'


def validate_settings(value):
    if (type(value) is not dict or set(value) != {'version', 'host', 'systemd'}
            or type(value['version']) is not int or value['version'] != 1
            or value['host'] != 'dancer' or SYSTEMD is None or value['systemd'] != SYSTEMD):
        raise ValueError('enrollment requires fixed opt-in native Dancer settings')
    return value


def load_settings():
    if hostname() != 'dancer':
        raise ValueError('enrollment requires Dancer')
    path = SETTINGS.resolve(strict=True)
    info = path.stat()
    if (not path.is_relative_to('/nix/store') or not stat.S_ISREG(info.st_mode)
            or info.st_uid != 0 or info.st_mode & 0o022):
        raise ValueError('enrollment requires immutable Nix configuration')
    value = validate_settings(json.loads(path.read_text(), object_pairs_hook=migration._unique))
    for relative in ('bin/systemd-cryptenroll', 'lib/systemd/systemd-measure'):
        tool = Path(value['systemd']) / relative
        actual = tool.resolve(strict=True)
        info = actual.stat()
        if (not actual.is_relative_to('/nix/store') or not stat.S_ISREG(info.st_mode)
                or info.st_uid != 0 or info.st_mode & 0o022 or not os.access(tool, os.X_OK)):
            raise ValueError('enrollment requires immutable pinned native tools')
    parent.load_settings()
    return value


def _issuer_bytes(path, expected):
    if _read_file(path, 0o644, max_size=16384) != expected:
        raise ValueError('approved issuer public file changed')
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    with os.fdopen(fd, 'rb') as file:
        info = os.fstat(file.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_ino != expected['inode']
                or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o644
                or info.st_nlink != 1 or info.st_size != expected['size']):
            raise ValueError('approved issuer public replaced before read')
        raw = file.read(16385)
    if (len(raw) != expected['size'] or hashlib.sha256(raw).hexdigest() != expected['sha256']
            or _read_file(path, 0o644, max_size=16384) != expected):
        raise ValueError('approved issuer public changed during read')
    return raw


def _settings_snapshot(closure):
    path = SETTINGS.resolve(strict=True)
    if path != (closure / 'etc' / SETTINGS.name).resolve(strict=True):
        raise ValueError('enrollment settings differ from booted source')
    return _read_file(path)


def _inventory(state):
    root = state / 'enrollment-observations'
    if not root.exists() and not root.is_symlink():
        root.mkdir(mode=0o700)
        migration._sync_directory(state)
    migration._directory(root)
    directory = Path(tempfile.mkdtemp(prefix='inventory.', dir=root))
    migration._sync_directory(root)
    settings = parent.load_settings()
    return parent.inventory(directory / 'objects', lambda argv: parent._run_tpm(settings, argv))


def _prior(state, config, run):
    issuer = migration.read_operation(state / 'migrations/issuer')
    persisted = migration.read_operation(state / 'migrations/parent')
    if issuer['phase'] != 'complete' or persisted['phase'] != 'complete':
        raise ValueError('enrollment requires completed issuer and explicit-parent operations')
    approved = parent.ParentGuard(state, config, run)
    evidence = persisted['receipts'][-1]['evidence']
    handle = approved.context['handle']
    if (evidence.get('approval') != {'context': approved.identity, 'handle': handle}
            or evidence.get('handle') != handle):
        raise ValueError('parent receipt differs from HUMAN-approved selector')
    public = bytes.fromhex(evidence['public'])
    validate_parent(public)
    expected = {'persistent': {**approved.context['inventory']['persistent'], f'0x{handle:08x}': public.hex()},
                'nv': approved.context['inventory']['nv'], 'owner_auth_empty': True}
    if evidence.get('inventory_after') != expected:
        raise ValueError('parent receipt inventory differs')
    return {'candidate': migration._candidate(issuer['receipts'][-1]['evidence']),
            'handle': handle, 'public': public.hex(), 'inventory': expected,
            'parent_context': approved.identity, 'parent_binding': approved.binding_identity,
            'parent_receipt': _read_file(state / 'migrations/parent/0003-complete.json', 0o600),
            'issuer_receipt': _read_file(state / 'migrations/issuer/0005-complete.json', 0o600)}


def _snapshot(state, config, run, *, header_guard, confirmation_stage=None):
    if (state / 'journal.json').exists() or (state / 'journal.json').is_symlink():
        raise ValueError('enrollment refuses pending publication')
    prior = _prior(state, config, run)
    live = _collect_runtime(config, run, header_guard=header_guard)
    if confirmation_stage == 'confirm':
        if (live['confirmation']['ActiveState'] != 'active'
                or live['confirmation']['SubState'] not in {'running', 'exited'}):
            raise ValueError('normal confirmation unit must actually be active')
    else:
        _confirmed(live)
    entry = live['boot']['entry']
    actual = {'entry_id': entry, 'closure': live['boot']['closure'], 'sha256': live['boot']['sha256'],
              'pcr_key_fingerprint': live['manifest']['images'][entry]['pcr_key_fingerprint']}
    if (migration._candidate(actual) != prior['candidate']
            or live['manifest']['default'] != entry or live['manifest']['known_good'] != entry
            or live['boot']['pcr_public_sha256'] != live['issuer']['files']['public.pem']['sha256']
            or _bits(Path(config['keys']['pcr_public']), run) != 2048):
        raise ValueError('enrollment requires the exact accepted and confirmed RSA2048 boot')
    return {'live': live, 'prior': prior, 'device': parent._device_snapshot(),
            'settings': _settings_snapshot(Path(live['boot']['closure'])),
            'parent_settings': parent._settings_snapshot(Path(live['boot']['closure'])),
            'code': _read_file(Path(__file__).resolve()),
            'verifier_code': _read_file(Path(__file__).with_name('tpm_enrollment.py')),
            'issuer_public': _read_file(Path(config['keys']['pcr_public']), 0o644)}


def arm_enrollment(state, config, run, approved_closure, *, manual_unlock_attested,
                   recovery_backup_attested, signing_backup_attested, firmware_risk_accepted,
                   trusted_enrollment_attested, hardware_primitives_attested, approve_rsa2048):
    if not all(value is True for value in (manual_unlock_attested, recovery_backup_attested,
            signing_backup_attested, firmware_risk_accepted, trusted_enrollment_attested,
            hardware_primitives_attested, approve_rsa2048)):
        raise ValueError('separate HUMAN manual/header/signing backup/risk/trusted-window/primitives/RSA2048 approval required')
    settings = load_settings()
    with installer_lock(state):
        migration.require_writer_allowed(state, 'install')
        if any(path.exists() or path.is_symlink() for path in (
                state / 'enrollment-approval-attempt.json', state / CONTEXT,
                state / 'migrations/enrollment')):
            raise ValueError('permanent enrollment approval/attempt exists; no replay')
        before = _snapshot(state, config, run, header_guard=_unenrolled_header)
        if str(approved_closure) != before['live']['boot']['closure']:
            raise ValueError('enrollment requires exact approved booted closure')
        attempt = migration._write_once(state, 'enrollment-approval-attempt.json',
                {'version': 1, 'scope': SCOPE, 'before': before})
        if _inventory(state) != before['prior']['inventory']:
            raise ValueError('approved ECC or existing object/NV inventory changed')
        if _snapshot(state, config, run, header_guard=_unenrolled_header) != before or load_settings() != settings:
            raise ValueError('enrollment approval baseline changed')
        context = migration._write_once(state, CONTEXT, {'version': 1, 'scope': SCOPE,
                'state_binding': migration._binding(state), 'before': before,
                'attempt': _read_file(attempt, 0o600)})
        migration._write_once(state, 'enrollment-maintenance-binding.json',
                {'version': 1, 'context': _read_file(context, 0o600)})
        return context


def accept_enrollment(state, config, run, *, electrical_cold_attested,
                      automatic_unlock_attested, manual_recovery_attested):
    """Record HUMAN attended acceptance; never boot, retry or infer coldness.

    HUMAN observes automatic unlocking and independently tests manual recovery.
    Different boot identity is necessary, not evidence of electrical coldness.
    An interrupted acceptance keeps its permanent barrier; no resume/repair API.
    """
    if not all(value is True for value in (electrical_cold_attested,
            automatic_unlock_attested, manual_recovery_attested)):
        raise ValueError('separate HUMAN cold/automatic/manual-recovery attestations required')
    with installer_lock(state):
        guard = EnrollmentGuard(state, config, run)
        operation = state / 'migrations/enrollment'
        binding = guard.check('accept')
        marker = migration._write_once(operation / 'artifacts', 'attended-acceptance-attempt.json',
                {'version': 1, **binding, 'electrical_cold_attested': True,
                 'automatic_unlock_attested': True, 'manual_recovery_attested': True})
        if guard.check('accept') != binding:
            raise ValueError('attended acceptance runtime changed; permanent attempt retained')
        evidence = {**binding['candidate'], 'approval': binding['approval'],
                    'boot_id': binding['boot_id'], 'header_after': binding['header'],
                    'acceptance_attempt': _read_file(marker, 0o600)}
        migration.record_phase(operation, 'attended-boot-accepted', evidence)
        if guard.check('accepted') != binding:
            raise ValueError('attended acceptance runtime changed after receipt')
        return migration.record_phase(operation, 'complete', evidence)


def dispatch(args, config, run):
    load_settings()  # Default-off/host/fixed tool gates precede state/key/TPM reads.
    state = Path(config['state_dir'])
    if args.command == 'enrollment-arm':
        return arm_enrollment(state, config, run, args.closure,
                manual_unlock_attested=args.manual_unlock_attested,
                recovery_backup_attested=args.recovery_backup_attested,
                signing_backup_attested=args.signing_backup_attested,
                firmware_risk_accepted=args.firmware_risk_accepted,
                trusted_enrollment_attested=args.trusted_enrollment_attested,
                hardware_primitives_attested=args.hardware_primitives_attested,
                approve_rsa2048=args.approve_rsa2048)
    if args.command == 'enrollment-accept':
        return accept_enrollment(state, config, run,
                electrical_cold_attested=args.electrical_cold_attested,
                automatic_unlock_attested=args.automatic_unlock_attested,
                manual_recovery_attested=args.manual_recovery_attested)
    if args.command == 'enrollment-enroll':
        from .tpm_enrollment import enroll_once
        guard = EnrollmentGuard(state, config, run)
        return enroll_once(state / 'migrations/enrollment', state, run, guard=guard)
    raise ValueError('unsupported separate enrollment command')


class EnrollmentGuard:
    def __init__(self, state, config, run):
        self.state, self.config, self.run = state, config, run
        self.settings = load_settings()
        self.path = state / CONTEXT
        if not self.path.exists() or self.path.is_symlink():
            raise ValueError('separate permanent HUMAN enrollment approval required')
        self.identity = _read_file(self.path, 0o600)
        self.binding_identity = _read_file(state / 'enrollment-maintenance-binding.json', 0o600)
        binding, _ = migration._read(state / 'enrollment-maintenance-binding.json')
        self.context, _ = migration._read(self.path)
        if (binding != {'version': 1, 'context': self.identity} or type(binding.get('version')) is not int
                or set(self.context) != {'version', 'scope', 'state_binding', 'before', 'attempt'}
                or type(self.context['version']) is not int or self.context['version'] != 1
                or self.context['scope'] != SCOPE or self.context['state_binding'] != migration._binding(state)
                or self.context['attempt'] != _read_file(state / 'enrollment-approval-attempt.json', 0o600)):
            raise ValueError('invalid separate permanent HUMAN enrollment approval')
        attempt, _ = migration._read(state / 'enrollment-approval-attempt.json')
        if attempt != {'version': 1, 'scope': SCOPE, 'before': self.context['before']}:
            raise ValueError('enrollment approval attempt differs')

    def check(self, stage):
        if stage not in {'before', 'written', 'verified', 'confirm', 'accept', 'accepted'}:
            raise ValueError('unknown enrollment guard stage')
        if (_read_file(self.path, 0o600) != self.identity
                or _read_file(self.state / 'enrollment-maintenance-binding.json', 0o600) != self.binding_identity
                or self.context['state_binding'] != migration._binding(self.state)
                or self.context['attempt'] != _read_file(self.state / 'enrollment-approval-attempt.json', 0o600)
                or load_settings() != self.settings):
            raise ValueError('enrollment approval/context/source drift')
        baseline = self.context['before']
        operation = self.state / 'migrations/enrollment'
        current = migration.read_operation(operation) if operation.exists() else None
        if current is not None:
            if (current['before'].get('approval') != self.identity
                    or current['before'].get('candidate') != baseline['prior']['candidate']):
                raise ValueError('foreign enrollment intent')
        if stage == 'written' and (current is None or current['phase'] != 'intent'):
            raise ValueError('only this first native write can be verified')
        if stage == 'verified' and (current is None or current['phase'] not in {'token-written', 'token-verified'}):
            raise ValueError('native token receipt required')
        if stage == 'before' and current is not None and current['phase'] != 'intent':
            raise ValueError('native attempt already progressed; no replay')
        postboot = stage in {'confirm', 'accept', 'accepted'}
        if postboot and (current is None or current['phase'] != (
                'attended-boot-accepted' if stage == 'accepted' else 'token-verified')):
            raise ValueError('exact verified enrollment phase required for confirmation/acceptance')
        def header_guard(header):
            original = baseline['live']['invariants']['header']
            if stage == 'before':
                if not _same_metadata(header, original): raise ValueError('approved unenrolled header changed')
                _unenrolled_header(header)
            else:
                verify_enrollment_delta(original, header, handle=baseline['prior']['handle'],
                        parent_public=bytes.fromhex(baseline['prior']['public']),
                        issuer_public=_issuer_bytes(Path(self.config['keys']['pcr_public']), baseline['issuer_public']))
                if (stage == 'verified' or postboot) and not _same_metadata(header, current['receipts'][0]['evidence']['header_after']):
                    raise ValueError('verified enrollment header changed')
        observed = _snapshot(self.state, self.config, self.run, header_guard=header_guard,
                             confirmation_stage=stage)
        normalized = copy.deepcopy(observed)
        normalized['live']['invariants']['header'] = baseline['live']['invariants']['header']
        if postboot:
            boot_id = observed['live']['boot']['boot_id']
            if (not isinstance(boot_id, str) or not boot_id
                    or boot_id == baseline['live']['boot']['boot_id']):
                raise ValueError('different actual post-enrollment boot required')
            normalized['live']['boot']['boot_id'] = baseline['live']['boot']['boot_id']
            normalized['live']['confirmation'] = baseline['live']['confirmation']
            # /dev is fresh devtmpfs on each boot. Only its ephemeral filesystem
            # number and inode may differ, never selector/type/owner/mode/rdev.
            # Exact full public-object/NV inventory below binds the TPM identity.
            if set(observed['device']) == set(baseline['device']) == {'inode', 'device', 'rdev', 'mode', 'uid', 'gid'}:
                for field in ('inode', 'device'):
                    normalized['device'][field] = baseline['device'][field]
            if stage == 'accepted':
                attended = current['receipts'][2]['evidence']
                if (attended.get('boot_id') != boot_id or attended.get('approval') != self.identity
                        or attended.get('acceptance_attempt') != _read_file(
                            operation / 'artifacts/attended-acceptance-attempt.json', 0o600)):
                    raise ValueError('attended acceptance boot/approval/attempt changed')
        if normalized != baseline or _inventory(self.state) != baseline['prior']['inventory']:
            raise ValueError('approved enrollment runtime/issuer/parent/trust/header/source drift')
        return {'approval': self.identity, 'candidate': baseline['prior']['candidate'],
                'header': observed['live']['invariants']['header'], 'boot_id': observed['live']['boot']['boot_id']}

    def invoke(self, artifacts):
        # Dedicated native terminal transport implemented in its own module.
        from .enrollment_terminal import invoke_native
        self.check('before')
        return invoke_native(self, artifacts)
