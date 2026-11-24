"""Create or unlock Dancer's login keyring without restarting Secret Service."""

import getpass
import os
from pathlib import Path
import shlex
import socket
import struct
import subprocess
import sys
import warnings

SERVICE = "org.freedesktop.secrets"
ROOT = "/org/freedesktop/secrets"
LOGIN = f"{ROOT}/collection/login"
SESSION = f"{ROOT}/collection/session"


def bus(*args):
    return shlex.split(subprocess.check_output(
        ["busctl", "--user", "--timeout=5s", *args], text=True
    ))


def service_call(*args):
    return bus("call", SERVICE, ROOT, "org.freedesktop.Secret.Service", *args)


def default_keyring():
    _, path = service_call("ReadAlias", "s", "default")
    return path


def is_unlocked(path):
    return bus("get-property", SERVICE, path, "org.freedesktop.Secret.Collection", "Locked") == ["b", "false"]


def unlock(password):
    # Same control operation as pam_gnome_keyring. See GNOME Keyring's
    # daemon/control/gkd-control-client.c and gkd-control-codes.h.
    # Secret Service's public Unlock method cannot take a password.
    dbus = "org.freedesktop.DBus"
    _, owner_pid = bus("call", dbus, "/org/freedesktop/DBus", dbus,
                       "GetConnectionUnixProcessID", "s", SERVICE)
    runtime = Path(os.environ.get("GNOME_KEYRING_CONTROL") or
                   Path(os.environ["XDG_RUNTIME_DIR"]) / "keyring")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as control:
        control.settimeout(5)
        control.connect(str(runtime / "control"))
        credentials = struct.Struct("=iII")
        pid, uid, _ = credentials.unpack(control.getsockopt(
            socket.SOL_SOCKET, socket.SO_PEERCRED, credentials.size
        ))
        if pid != int(owner_pid) or uid != os.geteuid():
            raise RuntimeError("The control socket does not belong to your Secret Service daemon.")
        # Linux credential handshake byte; then big-endian total size, unlock opcode,
        # and a length-prefixed password. No password in argv or the environment.
        control.sendall(b"\0" + struct.pack(">III", 12 + len(password), 1, len(password)))
        control.sendall(password)
        with control.makefile("rb") as reply:
            response = reply.read(8)
        if response == struct.pack(">II", 8, 1):
            raise RuntimeError("GNOME Keyring rejected the passphrase or could not create the keyring.")
        if response != struct.pack(">II", 8, 0):
            raise RuntimeError("Unexpected response from the GNOME Keyring control socket.")


def main():
    default = default_keyring()
    if default == SESSION:
        raise RuntimeError("The default keyring is temporary; set a password-protected default first.")
    if default != "/" and is_unlocked(default):
        print("Default keyring is already unlocked.")
        return
    if default not in ("/", LOGIN):
        raise RuntimeError("The default is not the login keyring. Unlock it separately; it was not changed.")

    _, _, *collections = bus("get-property", SERVICE, ROOT, "org.freedesktop.Secret.Service", "Collections")
    creating = LOGIN not in collections
    if creating or not is_unlocked(LOGIN):
        warnings.simplefilter("error", getpass.GetPassWarning)
        prompt = "Choose a new keyring passphrase: " if creating else "Keyring passphrase: "
        password = getpass.getpass(prompt)
        if not password or "\0" in password:
            raise RuntimeError("Use a non-empty passphrase without NUL characters.")
        if creating and password != getpass.getpass("Confirm the new keyring passphrase: "):
            raise RuntimeError("Passphrases do not match; the keyring was not created.")
        unlock(password.encode("utf-8"))
        del password

    if not is_unlocked(LOGIN):
        raise RuntimeError("The login keyring is still locked.")
    # Do not intentionally replace an existing alias. The API has no atomic
    # set-if-absent; first-time initialization should not run concurrently.
    default = default_keyring()
    if default == "/":
        service_call("SetAlias", "so", "default", LOGIN)
    if default_keyring() == SESSION or not is_unlocked(f"{ROOT}/aliases/default"):
        raise RuntimeError("No unlocked persistent default keyring is available.")
    print("Default keyring is unlocked.")


if __name__ == "__main__":
    try:
        main()
    except (EOFError, getpass.GetPassWarning, KeyboardInterrupt):
        sys.exit("unlock-keyring: Could not read a hidden passphrase from the terminal.")
    except subprocess.CalledProcessError:
        sys.exit("unlock-keyring: Could not query or configure Secret Service on the user bus.")
    except (OSError, RuntimeError, KeyError) as error:
        sys.exit(f"unlock-keyring: {error}")
