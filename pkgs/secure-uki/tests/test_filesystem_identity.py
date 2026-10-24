"""Durable identities distinguish real filesystems/subvolumes, not device order."""
import errno
import importlib
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


def module():
    if importlib.util.find_spec('secure_uki.filesystem_identity') is None:
        raise AssertionError('stable filesystem identity API missing')
    return importlib.import_module('secure_uki.filesystem_identity')


class FilesystemIdentityTests(unittest.TestCase):
    def test_fd_identity_is_stable_and_held_directory_distinguishes_replacement(self):
        api = module()
        from secure_uki.migration_state import _binding
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); original = root / 'state'; original.mkdir(mode=0o700)
            before = _binding(original)
            fd = os.open(original, os.O_RDONLY | os.O_DIRECTORY)
            try:
                original.rename(root / 'retained-state'); original.mkdir(mode=0o700)
                self.assertEqual(api.filesystem_identity(fd), before['filesystem'])
                self.assertNotEqual(_binding(original), before)
            finally:
                os.close(fd)

    def test_btrfs_ioctl_error_does_not_fallback_to_generic_fsid(self):
        api = module()
        with tempfile.TemporaryFile() as file:
            with patch.object(api, '_filesystem_type', return_value=0x9123683e), \
                    patch.object(api.fcntl, 'ioctl', side_effect=OSError(errno.ENOTTY, 'unsupported')):
                with self.assertRaises(OSError):
                    api.filesystem_identity(file.fileno())

    def test_zero_btrfs_uuid_or_invalid_subvolume_refuses_identity(self):
        api = module()
        for nonzero_uuid in (False, True):
            def invalid(_fd, command, buffer, *_args):
                if command == api.FS_INFO and nonzero_uuid:
                    buffer[16:32] = b'synthetic-uuid!!'
                return 0
            with self.subTest(nonzero_uuid=nonzero_uuid), tempfile.TemporaryFile() as file:
                with patch.object(api, '_filesystem_type', return_value=0x9123683e), \
                        patch.object(api.fcntl, 'ioctl', side_effect=invalid):
                    with self.assertRaises(ValueError):
                        api.filesystem_identity(file.fileno())

    def test_mismatched_filesystem_never_accepts_an_unchanged_inode_receipt(self):
        api = module()
        from secure_uki import migration_state as migration
        from secure_uki.publish import installer_lock
        with tempfile.TemporaryDirectory() as temp:
            state = Path(temp)
            with installer_lock(state):
                operation = migration.begin_operation(state, 'issuer', {'version': 1})
            with patch.object(migration, 'filesystem_identity', return_value={'type': 0, 'fsid': 'synthetic-other'}):
                with self.assertRaises(ValueError):
                    migration.read_operation(operation)


if __name__ == '__main__':
    unittest.main()
