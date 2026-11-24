"""Exercise the packaged helper with a real keyring on disposable session buses."""

import errno
import os
from pathlib import Path
import pty
import select
import subprocess
import sys
import time

SERVICE = "org.freedesktop.secrets"
PASSWORD = b"disposable test passphrase"


def helper(prompts, expected_status, message):
    pid, fd = pty.fork()
    if pid == 0:
        os.execlp("fish", "fish", "--no-config", "-c", "exec unlock-keyring")
    output = b""
    deadline = time.monotonic() + 10
    try:
        while select.select([fd], [], [], max(0, deadline - time.monotonic()))[0]:
            try:
                chunk = os.read(fd, 4096)
            except OSError as error:
                if error.errno == errno.EIO:  # PTY closed by child
                    break
                raise
            if not chunk:
                break
            output += chunk
            if prompts and output.endswith(prompts[0][0]):
                _, answer = prompts.pop(0)
                os.write(fd, answer + b"\n")
        else:
            os.kill(pid, 9)
            raise AssertionError(f"helper timed out: {output!r}")
    finally:
        os.close(fd)
        _, status = os.waitpid(pid, 0)
    assert not prompts and os.waitstatus_to_exitcode(status) == expected_status, output
    assert message in output, output
    assert PASSWORD not in output and b"wrong passphrase" not in output, output


def secret(*args, **kwargs):
    return subprocess.run(["secret-tool", *args], check=True, **kwargs).stdout


def owner():
    dbus = "org.freedesktop.DBus"
    return subprocess.check_output([
        "busctl", "--user", "call", dbus, "/org/freedesktop/DBus", dbus,
        "GetNameOwner", "s", SERVICE,
    ])


daemon = subprocess.Popen(["gnome-keyring-daemon", "--foreground", "--components=secrets"])
try:
    for _ in range(50):
        try:
            initial_owner = owner()
            break
        except subprocess.CalledProcessError:
            time.sleep(0.1)
    else:
        raise AssertionError("Secret Service did not start")

    secret("store", "--collection=/org/freedesktop/secrets/collection/session",
           "--label=Temporary", "test", "session", input=b"memory only")

    if sys.argv[1] == "create":
        new = b"Choose a new keyring passphrase: "
        confirm = b"Confirm the new keyring passphrase: "
        helper([(new, PASSWORD), (confirm, b"wrong passphrase")], 1, b"Passphrases do not match")
        assert not (Path(os.environ["XDG_DATA_HOME"]) / "keyrings/login.keyring").exists()
        helper([(new, PASSWORD), (confirm, PASSWORD)], 0, b"Default keyring is unlocked")
        secret("store", "--label=Persistent", "test", "disk", input=b"persisted")
    else:
        prompt = b"Keyring passphrase: "
        helper([(prompt, b"wrong passphrase")], 1, b"GNOME Keyring rejected the passphrase")
        assert owner() == initial_owner
        assert secret("lookup", "test", "session", capture_output=True).strip() == b"memory only"
        helper([(prompt, PASSWORD)], 0, b"Default keyring is unlocked")
        assert secret("lookup", "test", "disk", capture_output=True).strip() == b"persisted"

    helper([], 0, b"Default keyring is already unlocked")
    assert owner() == initial_owner
    assert secret("lookup", "test", "session", capture_output=True).strip() == b"memory only"
finally:
    daemon.terminate()
    daemon.wait(timeout=5)
