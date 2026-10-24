"""Explicit ECC parent validation; protected bytes are never public observations.

PUBLIC template/Name validation is not proof of ownership or hierarchy auth, nor
exclusion of privileged or firmware replacement. Only owned transient TPM context
files may be given to EvictControl: tpm2-tools treats persistent object inputs as
EVICTION, regardless of the separately requested destination slot.
"""
import struct


def validate_parent_handle(handle: int) -> int:
    # OWNER persistent range only. Default SRK/platform/transient selectors cannot
    # trigger default creation, automatic vacant-slot search or platform auth.
    if type(handle) is not int or not 0x81000002 <= handle < 0x81800000:
        raise ValueError('explicit unused owner-persistent nondefault parent required')
    return handle


def validate_parent(public: bytes, expected_public: bytes | None = None) -> dict:
    if not isinstance(public,bytes) or not 0 < len(public) <= 4096:
        raise ValueError('invalid protected TPM public object')
    offset=0
    def take(size):
        nonlocal offset
        if offset+size>len(public): raise ValueError('truncated protected TPM public object')
        value=public[offset:offset+size]; offset+=size
        return value
    def u16(): return struct.unpack('>H',take(2))[0]
    if u16()!=len(public)-2: raise ValueError('protected TPM public length differs')
    if (u16(),u16(),struct.unpack('>I',take(4))[0])!=(0x23,0x0b,0x30472):
        raise ValueError('approved ECC storage parent template required; no RSA fallback')
    if u16()!=0: raise ValueError('parent policy differs')
    if tuple(u16() for _ in range(6))!=(6,128,0x43,0x10,3,0x10):
        raise ValueError('approved ECC storage parent parameters differ')
    xraw=take(u16()); yraw=take(u16())
    if len(xraw)!=32 or len(yraw)!=32 or offset!=len(public):
        raise ValueError('invalid protected P256 point encoding')
    p=0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff
    b=0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b
    x=int.from_bytes(xraw,'big'); y=int.from_bytes(yraw,'big')
    if x>=p or y>=p or (y*y-x*x*x+3*x-b)%p:
        raise ValueError('protected parent point is not on P256')
    if expected_public is not None and (not isinstance(expected_public,bytes) or public!=expected_public):
        raise ValueError('parent identity differs from protected receipt')
    return {'type':'ECC','curve':'P256','name_algorithm':'sha256','exact_template':True}


def validate_transient_context(raw: bytes) -> None:
    # Pinned tpm2-tools5.7 files_save_context: BE magic/version/hierarchy/savedHandle/
    # sequence/TPM2B_CONTEXT_DATA. Serialized ESYS_TR or persistent context is NOT
    # interchangeable with an owned CreatePrimary output.
    if not isinstance(raw,bytes) or not 26 < len(raw) <= 65536:
        raise ValueError('invalid invocation-owned transient context')
    magic,version,hierarchy,handle,sequence,size=struct.unpack_from('>IIIIQH',raw)
    if (magic!=0xbadcc0de or version!=1 or hierarchy!=0x40000001
            or handle>>24!=0x80 or size!=len(raw)-26 or size==0):
        raise ValueError('only an owned OWNER transient context may be persisted')


def create_private_output(path):
    """New owned artifact only. Pinned tools reset umask to0117 (new files0660).

    Pre-create0600 with O_EXCL; their wb writes preserve it. Never chmod/repair an
    unexpected output or accept an existing filename. Retain stubs on uncertainty.
    """
    import os
    import stat
    from . import migration_state as migration
    migration._directory(path.parent)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
    try:
        info = os.fstat(fd)
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid()
                or stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1):
            raise ValueError('unsafe new private TPM output')
        os.fsync(fd)
    finally:
        os.close(fd)
    migration._sync_directory(path.parent)


def read_private_blob(path, *, limit):
    """Bounded held-fd bytes matching a private durable snapshot; never stdout."""
    import hashlib
    import os
    import stat
    from .filesystem_identity import filesystem_identity
    from .policy_rotation import _read_file
    expected = _read_file(path, 0o600, sync=True, max_size=limit)
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    with os.fdopen(fd, 'rb') as file:
        before = os.fstat(file.fileno())
        if (not stat.S_ISREG(before.st_mode) or before.st_uid != os.geteuid()
                or stat.S_IMODE(before.st_mode) != 0o600 or before.st_nlink != 1
                or before.st_ino != expected['inode'] or before.st_size != expected['size']
                or filesystem_identity(file.fileno()) != expected['filesystem']):
            raise ValueError('protected TPM blob replaced before read')
        raw = file.read(limit + 1)
        after = os.fstat(file.fileno())
        if (not 0 < len(raw) <= limit or len(raw) != before.st_size
                or (after.st_size, after.st_mtime_ns, after.st_ctime_ns)
                != (before.st_size, before.st_mtime_ns, before.st_ctime_ns)
                or hashlib.sha256(raw).hexdigest() != expected['sha256']):
            raise ValueError('protected TPM blob changed during read')
    return raw, expected


def provision_parent(operation, handle, state, run, *, guard):
    """One native explicit ECC provisioning attempt under separate HUMAN approval.

    Only this invocation's verified CreatePrimary context is persistent input.
    No rollback, retry, object eviction, global flush or authorization guessing.
    Kernel resource-manager connections release their transient objects on exit;
    protected context files/receipts remain. Trusted enrollment is NOT exclusion
    of a hostile privileged replacement. Caller must obtain physical permission.
    """
    from . import migration_state as migration
    from .parent_maintenance import DEVICE, ParentGuard, inventory
    from .publish import installer_lock
    validate_parent_handle(handle)
    if (type(guard) is not ParentGuard or guard.state != state or guard.run is not run
            or operation != state / 'migrations/parent' or handle != guard.context['handle']):
        raise ValueError('separate exact parent approval required')
    with installer_lock(state):
        # Even intent-only interruption cannot be replayed by this entry point.
        if operation.exists() or operation.is_symlink():
            raise ValueError('permanent parent attempt exists; no replay or recreation')
        binding = guard.check()
        before = guard.context['inventory']
        actual = migration.begin_operation(state, 'parent',
                {'version': 1, 'approval': binding, 'inventory': before})
        if actual != operation:
            raise ValueError('parent operation path differs')
        artifacts = operation / 'artifacts'
        artifacts.mkdir(mode=0o700)
        migration._sync_directory(operation)
        if inventory(artifacts / 'before', guard.command) != before:
            raise ValueError('approved unused parent inventory changed')
        guard.check()
        context = artifacts / 'owned.ctx'
        public_path = artifacts / 'transient.public'
        create_private_output(context)
        create_private_output(public_path)
        guard.command(['tpm2_createprimary', '-T', DEVICE, '-C', 'o', '-G', 'ecc256:null:aes128cfb',
                       '-g', 'sha256', '-a', '0x30472', '-c', str(context), '-f', 'tss', '-o', str(public_path)])
        context_bytes, context_identity = read_private_blob(context, limit=65536)
        validate_transient_context(context_bytes)
        public, _ = read_private_blob(public_path, limit=4096)
        validate_parent(public)
        live_public = artifacts / 'live-transient.public'
        create_private_output(live_public)
        guard.command(['tpm2_readpublic', '-T', DEVICE, '-c', str(context), '-f', 'tss', '-o', str(live_public)])
        validate_parent(read_private_blob(live_public, limit=4096)[0], expected_public=public)
        if read_private_blob(context, limit=65536)[1] != context_identity:
            raise ValueError('invocation-owned context changed')
        evidence = {'handle': handle, 'public': public.hex(), 'owned_context': context_identity,
                    'approval': binding}
        migration._sync_directory(artifacts)
        migration.record_phase(operation, 'transient-verified', evidence)
        if inventory(artifacts / 'pre-persist', guard.command) != before:
            raise ValueError('parent slot or existing object/NV changed before persistence')
        guard.check()
        # Persistent inputs are forbidden, even if destination is approved/empty.
        if read_private_blob(context, limit=65536)[1] != context_identity:
            raise ValueError('invocation-owned context changed before persistence')
        guard.command(['tpm2_evictcontrol', '-T', DEVICE, '-C', 'o', '-c', str(context), f'0x{handle:08x}'])
        after = inventory(artifacts / 'after', guard.command)
        expected = {'persistent': {**before['persistent'], f'0x{handle:08x}': public.hex()},
                    'nv': before['nv'], 'owner_auth_empty': True}
        if after != expected:
            raise ValueError('persisted parent or existing object/NV inventory differs')
        validate_parent(bytes.fromhex(after['persistent'][f'0x{handle:08x}']), expected_public=public)
        guard.check()
        evidence = {**evidence, 'inventory_after': after}
        migration.record_phase(operation, 'persistent-verified', evidence)
        guard.check()
        return migration.record_phase(operation, 'complete', evidence)
