"""Real harmless child/PTY timeout and parent-death tests; no TPM/LUKS transport."""
import importlib
import os
from pathlib import Path
import pty
import signal
import sys
import tempfile
import time
import unittest
from unittest.mock import patch


def api():
    try:
        return importlib.import_module('secure_uki.enrollment_terminal')
    except ModuleNotFoundError as error:
        if error.name != 'secure_uki.enrollment_terminal': raise
        raise AssertionError('dedicated native terminal transport missing') from None


class NativeTerminalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.root.chmod(0o700)
        self.master, self.slave = pty.openpty()
        self.addCleanup(os.close, self.master)
        self.addCleanup(os.close, self.slave)

    def test_child_has_scrubbed_environment_and_direct_tty_stdin_private_output(self):
        module = api()
        output = self.root / 'private-diagnostics'
        with output.open('xb') as diagnostics, patch.dict(os.environ, {'PASSWORD': 'invalid-fixture', 'LD_PRELOAD': '/invalid-loader'}):
            exit_code = module._execute([sys.executable, '-I', '-B', '-c',
                'import os,sys; assert os.isatty(0); assert "PASSWORD" not in os.environ; assert "LD_PRELOAD" not in os.environ; print("safe-child-result")'],
                diagnostics, self.slave, timeout=5)
        self.assertEqual(exit_code, 0)
        self.assertEqual(output.read_bytes(), b'safe-child-result\n')

    def test_timeout_kills_child_and_reports_uncertainty_without_retry(self):
        module = api()
        output = self.root / 'private-timeout'
        with output.open('xb') as diagnostics, self.assertRaises(RuntimeError):
            module._execute([sys.executable, '-I', '-B', '-c', 'import time; time.sleep(30)'],
                            diagnostics, self.slave, timeout=0.1)
        self.assertTrue(output.is_file())

    def test_sigkill_of_controller_kills_its_direct_native_child(self):
        module = api()
        pid_file = self.root / 'synthetic-child.pid'
        controller = os.fork()
        if controller == 0:
            with (self.root / 'private-child').open('xb') as diagnostics:
                module._execute([sys.executable, '-I', '-B', '-c',
                    'import os,time; from pathlib import Path; Path(' + repr(str(pid_file)) + ').write_text(str(os.getpid())); time.sleep(30)'],
                    diagnostics, self.slave, timeout=35)
            os._exit(2)
        deadline = time.monotonic() + 5
        while not pid_file.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        self.assertTrue(pid_file.exists())
        child = int(pid_file.read_text())
        os.kill(controller, signal.SIGKILL)
        _, status = os.waitpid(controller, 0)
        self.assertTrue(os.WIFSIGNALED(status))
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            process = Path('/proc') / str(child) / 'status'
            if not process.exists() or '\nState:\tZ' in process.read_text(): break
            time.sleep(0.02)
        else:
            os.kill(child, signal.SIGKILL)
            self.fail('native child survived controller death')


if __name__ == '__main__': unittest.main()
