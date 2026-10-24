"""Opt-in HUMAN-approved issuer maintenance; no TPM transport or LUKS writes.

Root file permissions are not human authorization and do not exclude hostile root.
The arm command requires explicit HUMAN attestations, an exact actual signed boot
and permanent historical enforcement binding. Its one-shot receipt freezes that
accepted runtime. Commands never generate approval, restart confirmation or repair
an uncertain operation. All collected unique identities remain private.
"""
import hashlib
import os
from pathlib import Path
import re
import stat

from . import migration_state as migration
from .metadata import Keys, Tools, read_generation
from .policy_rotation import _bits, _generation_snapshot, _pair_snapshot, _read_file
from .prepare import OPENSSL
from .publish import _image_hash, _verify_retained, installer_lock, load_manifest

SETTINGS = Path('/etc/secure-uki-maintenance.json')
CONTEXT = 'issuer-maintenance.json'
GLOBAL = '8be4df61-93ca-11d2-aa0d-00e098032b8c'
DATABASE = 'd719b2cb-3d3a-4596-a3bc-dad00e67656f'
VARIABLES = ('PK','KEK','db','dbx','SecureBoot','SetupMode')


def hostname():
    return Path('/proc/sys/kernel/hostname').read_text().strip()


def validate_settings(value):
    from .cli import NIX_TOOL
    if (not isinstance(value,dict) or set(value)!={'version','host','luks_device','esp_device','lsattr'}
            or type(value['version']) is not int or value['version']!=1
            or value['host']!='dancer' or value['luks_device']!='/dev/nvme0n1p2'
            or value['esp_device']!='/dev/nvme0n1p1'
            or not isinstance(value['lsattr'],str) or not NIX_TOOL.fullmatch(value['lsattr'])
            or any(part in {'.','..'} for part in Path(value['lsattr']).parts)):
        raise ValueError('issuer maintenance is not a fixed opt-in Dancer configuration')
    return value


def load_settings():
    from .cli import _unique_object
    import json
    path=SETTINGS.resolve(strict=True); tool=None
    for item in (path,):
        info=item.stat()
        if not item.is_relative_to('/nix/store') or not stat.S_ISREG(info.st_mode) or info.st_uid!=0 or info.st_mode & 0o022:
            raise ValueError('issuer maintenance requires immutable Nix configuration')
    value=validate_settings(json.loads(path.read_text(),object_pairs_hook=_unique_object))
    tool=Path(value['lsattr']).resolve(strict=True); info=tool.stat()
    if not tool.is_relative_to('/nix/store') or not tool.is_file() or info.st_uid!=0 or info.st_mode & 0o022 or not os.access(tool,os.X_OK):
        raise ValueError('issuer maintenance requires pinned lsattr')
    return value


def _private_hash(path):
    return _read_file(path,0o600)['sha256']


def _authority_file(path, modes):
    # sbctl certificates are owner-read-only; its GUID inherits the creation
    # umask. Admit only each caller's known modes, then retain the exact observed
    # mode and all owner/single-link/no-follow checks. Never repair input metadata
    # or use the immutable Nix-public-source exception for these live files.
    mode=stat.S_IMODE(path.lstat().st_mode)
    if mode not in modes: raise ValueError('unsafe Secure Boot authority file mode')
    return _read_file(path,mode)


def _history(state, trust):
    # Existing enforcement history is read-only: never create/restart/rewrite it.
    witness, _=migration._read(state/'enforcement-first-boot.json')
    report_text=witness.get('report','')
    if not isinstance(report_text,str) or not re.fullmatch(re.escape(str(state))+r'/enforcement\.[A-Za-z0-9_]{8}/accepted\.json',report_text):
        raise ValueError('original enforcement report binding required')
    report=Path(report_text); data,digest=migration._read(report)
    if (digest!=witness.get('report_sha256') or data.get('stage')!='after-enable'
            or data.get('secure_boot')!=1 or data.get('anchor')!=witness.get('anchor')
            or data.get('boot_id')!=witness.get('boot_id')):
        raise ValueError('original enforcement witness changed')
    hashes={'witness':_private_hash(state/'enforcement-first-boot.json'),
            'enrollment_intent':_private_hash(state/'enrollment-attempt.json'),'report':digest}
    evidence=report.parent/'evidence'; migration._directory(evidence)
    for name in VARIABLES:
        prior=_private_hash(evidence/(name+'.efivar'))
        if prior!=trust[name]['sha256']:
            raise ValueError('trust no longer matches original enforced evidence')
        hashes[name]=prior
    for name in ('PK','KEK','db'):
        prior=_private_hash(evidence/('owner-'+name+'.pem'))
        actual=_authority_file(Path('/var/lib/sbctl/keys')/name/(name+'.pem'),(0o400,0o644))['sha256']
        if prior!=actual: raise ValueError('original owner certificate changed')
        hashes['owner-'+name]=prior
    prior=_private_hash(evidence/'owner-guid.txt')
    identity=_authority_file(Path('/var/lib/sbctl/GUID'),(0o600,0o644))
    if prior!=identity['sha256']: raise ValueError('original owner identity changed')
    hashes['owner-guid']=prior
    hashes['owner-guid-file']=identity
    return hashes


def _trust(run, settings):
    result={}
    for name in VARIABLES:
        guid=DATABASE if name in ('db','dbx') else GLOBAL
        path=Path('/sys/firmware/efi/efivars')/(name+'-'+guid)
        expected=path.lstat()
        if not stat.S_ISREG(expected.st_mode) or expected.st_uid!=0 or expected.st_mode & 0o022:
            raise ValueError('unsafe live trust variable')
        fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_CLOEXEC)
        try:
            info=os.fstat(fd)
            if (info.st_dev,info.st_ino)!=(expected.st_dev,expected.st_ino): raise ValueError('trust replaced before read')
            chunks=[]; total=0
            while True:
                data=os.read(fd,65536)
                if not data: break
                total+=len(data)
                if total>1024*1024: raise ValueError('oversized trust variable')
                chunks.append(data)
            raw=b''.join(chunks)
        finally: os.close(fd)
        if len(raw)<5: raise ValueError('invalid live trust variable')
        if name in ('SecureBoot','SetupMode') and raw[4:]!=bytes([1 if name=='SecureBoot' else 0]):
            raise ValueError('enforced Secure Boot/UserMode required')
        flags=None
        if name in ('PK','KEK','db','dbx'):
            output=run([settings['lsattr'],'-d',str(path)]).split()
            if len(output)!=2 or output[1]!=str(path) or 'i' not in output[0]:
                raise ValueError('required trust immutable flag missing')
            flags=output[0]
        result[name]={'sha256':hashlib.sha256(raw).hexdigest(),'flags':flags}
    return result


def _unenrolled_header(header):
    if not isinstance(header, dict) or header.get('tokens') != {}:
        raise ValueError('issuer maintenance requires unenrolled LUKS header')


def collect_runtime(config, run):
    """Issuer-only collector: always unenrolled, no public bypass parameters."""
    return _collect_runtime(config, run, header_guard=_unenrolled_header)


def _collect_runtime(config, run, *, header_guard):
    """Internal shared live checks; producer must supply its fixed header gate.

    The gate runs immediately after the fixed-device header read, before key/trust
    reads. This function is not an authorization API or configurable CLI waiver.
    Host/mount/source/trust/signature/readiness checks are unconditional.
    """
    if hostname()!='dancer': raise ValueError('issuer maintenance requires Dancer')
    from .cli import CONFIG_PATH, check_augmentations, check_initrd_secrets, check_mounts
    import json
    settings=load_settings()
    if config['state_filesystem']!='btrfs': raise ValueError('issuer maintenance requires encrypted Btrfs')
    check_mounts(config,run)
    for device in (settings['luks_device'],settings['esp_device'],config['encrypted_device']):
        if not stat.S_ISBLK(Path(device).stat().st_mode): raise ValueError('fixed encrypted/ESP backing devices must be block devices')
    state=Path(config['state_dir']); esp=Path(config['esp'])
    migration._directory(state); migration._directory(Path('/var/lib/sbctl'))
    check_augmentations(esp)
    closure=Path('/run/booted-system').resolve(strict=True)
    if (not migration.CLOSURE.fullmatch(str(closure)) or Path('/run/current-system').resolve(strict=True)!=closure
            or Path('/nix/var/nix/profiles/system').resolve(strict=True)!=closure):
        raise ValueError('exact booted/current/system-profile maintenance closure required')
    for path in (CONFIG_PATH,SETTINGS):
        if path.resolve(strict=True)!=(closure/'etc'/path.name).resolve(strict=True):
            raise ValueError('live configuration differs from booted maintenance source')
    package=next((path for path in Path(__file__).resolve().parents if path.parent==Path('/nix/store')),None)
    if package is None or (closure/'sw/bin/secure-uki').resolve(strict=True)!=(package/'bin/secure-uki').resolve(strict=True):
        raise ValueError('running maintenance code differs from booted source')
    generation=read_generation(closure); check_initrd_secrets(closure)
    status=run([config['tools']['cryptsetup'],'status',config['encrypted_device']])
    match=re.search(r'^\s*device:\s*(/dev/[^\s]+)\s*$',status,re.MULTILINE)
    if not match or Path(match[1]).resolve(strict=True)!=Path(settings['luks_device']).resolve(strict=True):
        raise ValueError('encrypted mapper backing device differs')
    mount=json.loads(run([config['tools']['findmnt'],'--json','--first-only','--target','/boot','--output','SOURCE']))
    rows=mount.get('filesystems',[])
    if len(rows)!=1 or Path(rows[0].get('source','')).resolve(strict=True)!=Path(settings['esp_device']).resolve(strict=True):
        raise ValueError('actual ESP device differs')
    header=json.loads(run([config['tools']['cryptsetup'],'luksDump','--dump-json-metadata',settings['luks_device']]),
                      object_pairs_hook=migration._unique,parse_constant=migration._nonfinite)
    if not isinstance(header,dict): raise ValueError('invalid fixed-device LUKS header')
    header_guard(header)
    for unit in ('systemd-tpm2-setup.service','systemd-tpm2-setup-early.service'):
        path=closure/'etc/systemd/system'/unit
        if not path.is_symlink() or str(path.readlink())!='/dev/null' or run(['systemctl','show',unit,'-p','LoadState','--value']).strip()!='masked':
            raise ValueError('automatic TPM setup must remain masked')
    if run(['systemctl','is-system-running']).strip()!='running' or run(['systemctl','is-active','multi-user.target']).strip()!='active':
        raise ValueError('maintenance system is not actually ready')
    confirmation={field:run(['systemctl','show','secure-uki-confirm','-p',field,'--value']).strip()
                  for field in ('ActiveState','SubState','Result','ExecMainStatus')}
    loaded=run(['bootctl','--esp-path=/boot','--print-stub-path']).strip()
    entry=Path(loaded).name
    if not migration.ENTRY.fullmatch(entry) or loaded!=str(esp/'EFI/Linux'/entry): raise ValueError('actual signed maintenance UKI required')
    manifest=load_manifest(state)
    if entry not in manifest['images'] or manifest['images'][entry]['closure']!=str(closure): raise ValueError('loaded maintenance manifest differs')
    image_hash=_image_hash(esp/'EFI/Linux'/entry)
    if image_hash!=manifest['images'][entry]['sha256']: raise ValueError('loaded maintenance UKI changed')
    keys=Keys(**{key:Path(value) for key,value in config['keys'].items()})
    tools=Tools(**{key:Path(config['tools'][key]) for key in Tools.__dataclass_fields__})
    _verify_retained(manifest,esp,tools,keys,run,state)
    inspected=json.loads(run([str(tools.ukify),'--json=short','inspect',loaded]),object_pairs_hook=migration._unique)
    policy_public=inspected.get('.pcrpkey',{}).get('sha256')
    if not isinstance(policy_public,str) or not migration.HASH.fullmatch(policy_public):
        raise ValueError('loaded UKI policy public key cannot be verified')
    if run([OPENSSL,'pkey','-passin','pass:','-in',str(keys.pcr_private),'-pubout']).strip()!=run([OPENSSL,'pkey','-pubin','-in',str(keys.pcr_public),'-pubout']).strip():
        raise ValueError('active PCR issuer pair differs')
    pairs={}
    for name in ('PK','KEK','db'):
        directory=Path('/var/lib/sbctl/keys')/name; migration._directory(directory)
        private=directory/(name+'.key'); public=directory/(name+'.pem')
        mode=stat.S_IMODE(private.lstat().st_mode)
        if mode not in (0o400,0o600): raise ValueError('unsafe Secure Boot private key mode')
        pairs[name]={'private':_read_file(private,mode),'public':_authority_file(public,(0o400,0o644))}
        if run([OPENSSL,'pkey','-passin','pass:','-in',str(private),'-pubout']).strip()!=run([OPENSSL,'x509','-in',str(public),'-pubkey','-noout']).strip():
            raise ValueError('Secure Boot certificate pairing differs')
    trust=_trust(run,settings)
    invariants={'closure':str(closure),'source':_generation_snapshot(generation),
                'config':{str(path):_read_file(path.resolve(strict=True)) for path in (CONFIG_PATH,SETTINGS)},
                'code':_read_file(Path(__file__).resolve()),'trust':trust,'sb_pairs':pairs,'header':header,
                'mounts':{'state':migration._binding(state),'sbctl':migration._binding(Path('/var/lib/sbctl'))},
                'history':_history(state,trust)}
    return {'invariants':invariants,'boot':{'closure':str(closure),'entry':entry,'sha256':image_hash,
            'boot_id':Path('/proc/sys/kernel/random/boot_id').read_text().strip(),'pcr_public_sha256':policy_public},
            'issuer':_pair_snapshot(state/'pcr-signing'),'manifest':manifest,'confirmation':confirmation}


def _confirmed(live):
    if live['confirmation']!={'ActiveState':'active','SubState':'exited','Result':'success','ExecMainStatus':'0'}:
        raise ValueError('actual boot confirmation must already have succeeded')


def arm_runtime(state,config,run,approved_closure,*,manual_unlock_attested,recovery_backup_attested,approve_rsa2048):
    if not all(value is True for value in (manual_unlock_attested,recovery_backup_attested,approve_rsa2048)):
        raise ValueError('explicit HUMAN manual boot/recovery backup/RSA2048 approval required')
    with installer_lock(state):
        migration.require_writer_allowed(state,'install')
        if (state/CONTEXT).exists() or (state/CONTEXT).is_symlink(): raise ValueError('permanent maintenance approval already exists')
        if (state/'journal.json').exists() or (state/'journal.json').is_symlink():
            raise ValueError('maintenance approval refuses pending publication')
        before=collect_runtime(config,run)
        _confirmed(before)
        if before['boot']['pcr_public_sha256']!=before['issuer']['files']['public.pem']['sha256']:
            raise ValueError('loaded UKI PCR key differs from the active issuer')
        if str(approved_closure)!=before['boot']['closure'] or before['manifest']['default']!=before['boot']['entry'] or before['manifest']['known_good']!=before['boot']['entry']:
            raise ValueError('approved exact maintenance boot has not been confirmed')
        if _bits(Path(config['keys']['pcr_public']),run)!=3072:
            raise ValueError('approved baseline must use software RSA3072')
        if collect_runtime(config,run)!=before: raise ValueError('maintenance baseline drifted before approval record')
        context=migration._write_once(state,CONTEXT,{'version':1,'scope':'human-approved-software-issuer-only',
                'state_binding':migration._binding(state),'before':before})
        migration._write_once(state,'issuer-maintenance-binding.json',{'version':1,'context':_read_file(context,0o600)})
        return context


def dispatch(args,config,run):
    """Fixed CLI entry; opts/attestations cannot select paths, tools or TPM actions."""
    if hostname()!='dancer': raise ValueError('issuer maintenance requires Dancer')
    load_settings()  # Default disabled, BEFORE reading state/keys.
    state=Path(config['state_dir']); esp=Path(config['esp'])
    if args.command=='issuer-arm':
        return arm_runtime(state,config,run,args.closure,
                           manual_unlock_attested=args.manual_unlock_attested,
                           recovery_backup_attested=args.recovery_backup_attested,
                           approve_rsa2048=args.approve_rsa2048)
    guard=RuntimeGuard(state,config,run)
    closure=Path(guard.context['before']['boot']['closure'])
    keys=Keys(**{name:Path(value) for name,value in config['keys'].items()})
    tools=Tools(**{name:Path(config['tools'][name]) for name in Tools.__dataclass_fields__})
    from .policy_rotation import prepare_rotation,commit_rotation,accept_rotation
    operation=state/'migrations/issuer'
    if args.command=='issuer-prepare':
        return prepare_rotation(read_generation(closure),tools,keys,state,run,guard=guard)
    if args.command=='issuer-commit':
        return commit_rotation(operation,read_generation(closure),tools,keys,esp,state,run,guard=guard)
    if args.command=='issuer-accept':
        loaded=Path(run(['bootctl','--esp-path=/boot','--print-stub-path']).strip()).name
        return accept_rotation(operation,loaded,closure,esp,state,run,tools=tools,keys=keys,
                               manual_unlock_attested=args.manual_unlock_attested,guard=guard)
    raise ValueError('unsupported issuer command')


class RuntimeGuard:
    def __init__(self,state,config,run):
        self.state,self.config,self.run=state,config,run
        self.path=state/CONTEXT
        self.identity=_read_file(self.path,0o600)
        receipt,_=migration._read(state/'issuer-maintenance-binding.json')
        if (set(receipt)!={'version','context'} or type(receipt['version']) is not int
                or receipt['version']!=1 or receipt['context']!=self.identity):
            raise ValueError('permanent maintenance approval binding differs')
        self.context,_=migration._read(self.path)
        if (set(self.context)!={'version','scope','state_binding','before'} or type(self.context['version']) is not int
                or self.context['version']!=1 or self.context['scope']!='human-approved-software-issuer-only'
                or self.context['state_binding']!=migration._binding(state)):
            raise ValueError('invalid permanent HUMAN maintenance approval')

    def __call__(self,stage):
        if stage not in {'prepare','commit','published','confirm','accept'}: raise ValueError('unknown maintenance guard stage')
        if _read_file(self.path,0o600)!=self.identity: raise ValueError('maintenance approval record replaced')
        live=collect_runtime(self.config,self.run); baseline=self.context['before']
        if stage!='confirm': _confirmed(live)
        elif live['confirmation']['ActiveState']!='active' or live['confirmation']['SubState'] not in {'running','exited'}:
            raise ValueError('confirmation unit is not actually active')
        binding={'closure':baseline['boot']['closure'],'context':self.identity}
        if live['invariants']!=baseline['invariants']: raise ValueError('accepted runtime/source/mount/trust/header/history drift')
        if stage in {'prepare','commit'}:
            if any(live[key]!=baseline[key] for key in ('boot','issuer','manifest')):
                raise ValueError('approved pre-rotation boot/issuer/manifest drift')
            if stage=='commit':
                current=migration.read_operation(self.state/'migrations/issuer')
                if current['before'].get('maintenance')!=binding: raise ValueError('operation was not prepared under this approval')
        else:
            current=migration.read_operation(self.state/'migrations/issuer')
            if current['before'].get('maintenance')!=binding: raise ValueError('foreign maintenance operation')
            evidence=current['receipts'][0]['evidence']
            if live['issuer']!=evidence['staged_pair'] or live['manifest']['default']!=evidence['entry_id']:
                raise ValueError('published issuer/default changed')
            if stage in {'accept','confirm'} and (live['boot']['entry']!=evidence['entry_id'] or live['boot']['sha256']!=evidence['sha256']
                    or live['boot']['boot_id']==baseline['boot']['boot_id'] or (stage=='accept' and live['manifest']['known_good']!=evidence['entry_id'])):
                raise ValueError('exact new manually booted/confirmed image required')
        return binding
