"""The unfinished installer must never report a successful installation."""

import subprocess
import sys
import unittest


class DisabledCLITests(unittest.TestCase):
    def test_install_command_is_nonoperational(self):
        result = subprocess.run(
            [sys.executable, "-m", "secure_uki.cli", "install", "/nonexistent-system"],
            capture_output=True, text=True, check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("disabled", result.stderr)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
