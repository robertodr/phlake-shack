"""Linux durable filesystem identity for protected receipts, never stdout.

st_dev remains useful for same-boot race/cross-device checks, not persistence:
Btrfs assigns anonymous device numbers by mount order. Bind its full filesystem
UUID AND subvolume ID instead. No fallback after a Btrfs ioctl failure. Generic
non-Btrfs disposable filesystems use their kernel fsid and filesystem type.
This does not establish encryption/host approval or exclude privileged actors.
"""

import ctypes
import fcntl
import os
import struct

BTRFS_MAGIC = 0x9123683E
# Linux x86_64 UAPI: FS_INFO(1024 bytes), GET_SUBVOL_INFO(504 bytes).
FS_INFO = 0x8400941F
SUBVOL_INFO = 0x81F8943C


def _filesystem_type(fd):
    libc = ctypes.CDLL(None, use_errno=True)
    function = libc.fstatfs
    function.argtypes = [ctypes.c_int, ctypes.c_void_p]
    function.restype = ctypes.c_int
    buffer = ctypes.create_string_buffer(256)
    if function(fd, buffer) != 0:
        raise OSError(ctypes.get_errno(), "cannot identify protected filesystem")
    return struct.unpack_from("=q", buffer.raw)[0]


def filesystem_identity(fd):
    """Identity of the pinned open object; never use a pathname after opening."""
    kind = _filesystem_type(fd)
    if kind == BTRFS_MAGIC:
        fs = bytearray(1024)
        fcntl.ioctl(fd, FS_INFO, fs, True)
        subvolume = bytearray(504)
        fcntl.ioctl(fd, SUBVOL_INFO, subvolume, True)
        uuid = bytes(fs[16:32])
        tree = struct.unpack_from("=Q", subvolume)[0]
        if not any(uuid) or (tree != 5 and tree < 256):
            raise ValueError("invalid protected Btrfs filesystem identity")
        return {"type": kind, "uuid": uuid.hex(), "subvolume": tree}
    fsid = os.fstatvfs(fd).f_fsid
    if type(fsid) is not int or fsid == 0:
        raise ValueError("protected filesystem identity unavailable")
    return {"type": kind, "fsid": str(fsid)}
