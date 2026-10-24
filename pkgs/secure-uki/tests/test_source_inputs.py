"""Immutable public Nix source is distinct from private rotation/state artifacts."""
import os
from pathlib import Path
import stat
import tempfile
from types import SimpleNamespace
import unittest

from secure_uki import policy_rotation as rotation


class SourceInputTests(unittest.TestCase):
    def test_only_readonly_root_owned_regular_unambiguous_store_source_can_share_links(self):
        function = getattr(rotation, '_immutable_source', None)
        self.assertTrue(callable(function), 'immutable source link classifier missing')
        path = Path('/nix/store/' + 'a' * 32 + '-fixture/lib/module.py')
        info = dict(st_mode=stat.S_IFREG | 0o444, st_uid=0, st_nlink=2)
        self.assertTrue(function(path, SimpleNamespace(**info)))
        for changes in ({'st_uid': 1000}, {'st_mode': stat.S_IFREG | 0o644},
                        {'st_mode': stat.S_IFLNK | 0o444}, {'st_nlink': 0}):
            self.assertFalse(function(path, SimpleNamespace(**{**info, **changes})))
        for bad in (Path('/tmp/module.py'), Path('/nix/store/../etc/module.py')):
            self.assertFalse(function(bad, SimpleNamespace(**info)))

    def test_private_and_nonstore_hardlinks_remain_refused_without_repair(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'private'
            path.write_bytes(b'synthetic data')
            path.chmod(0o600)
            os.link(path, Path(directory) / 'alias')
            for mode in (None, 0o600):
                with self.assertRaises(ValueError):
                    rotation._read_file(path, mode)
            self.assertEqual(path.stat().st_nlink, 2)
            self.assertEqual(path.read_bytes(), b'synthetic data')


if __name__ == '__main__':
    unittest.main()
