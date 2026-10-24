"""Pinned native human-terminal transport; never reads/brokers a password.

Direct child gets scrubbed environment, private diagnostics and Linux parent-death
SIGKILL. A timeout/failure leaves permanent intent/artifacts; no retry or repair.
"""
import ctypes
import json
import os
from pathlib import Path
import signal
import stat
import subprocess

from . import migration_state as migration
from .policy_rotation import _read_file
from .tpm_enrollment import PUBLIC_KEY, SIGNATURE, enrollment_arguments, terminal_environment
from .tpm_parent import create_private_output, read_private_blob


def _execute(argv, output, tty, *, timeout, stderr=None):
    owner = os.getpid()
    def parent_death():
        libc = ctypes.CDLL(None, use_errno=True)
        if libc.prctl(1, signal.SIGKILL, 0, 0, 0) != 0:
            os._exit(125)
        if os.getppid() != owner:
            os.kill(os.getpid(), signal.SIGKILL)
    try:
        with subprocess.Popen(argv, stdin=tty if tty >= 0 else subprocess.DEVNULL,
                stdout=output, stderr=stderr if stderr is not None else output,
                env=terminal_environment(), close_fds=True, preexec_fn=parent_death) as child:
            try:
                return child.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
                raise RuntimeError('native command timed out; outcome uncertain, no retry') from None
    except OSError:
        raise RuntimeError('native command could not execute; intent retained, no retry') from None


def _output(path):
    create_private_output(path)
    fd = os.open(path, os.O_WRONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    info = os.fstat(fd)
    if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid()
            or stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1 or info.st_size != 0):
        os.close(fd)
        raise ValueError('unsafe native private output')
    return os.fdopen(fd, 'wb')


def invoke_native(guard, artifacts):
    from .enrollment_maintenance import EnrollmentGuard
    if type(guard) is not EnrollmentGuard or artifacts != guard.state / 'migrations/enrollment/artifacts':
        raise ValueError('separate exact enrollment transport authority required')
    current = migration.read_operation(artifacts.parent)
    if (current['phase'] != 'intent' or current['before'].get('approval') != guard.identity
            or current['before'].get('candidate') != guard.context['before']['prior']['candidate']):
        raise ValueError('native invocation requires this exact permanent first intent')
    if (str(artifacts / 'userspace-signature.json') != SIGNATURE
            or guard.config['keys']['pcr_public'] != PUBLIC_KEY):
        raise ValueError('native enrollment requires fixed production staging/public-key paths')
    migration._write_once(artifacts, 'native-execution-attempt.json',
                         {'version': 1, 'approval': guard.identity})
    # A HUMAN controlling terminal is mandatory. Native ask-password itself owns
    # terminal echo handling and password memory. The agent/library never reads it.
    try:
        tty = os.open('/dev/tty', os.O_RDWR | os.O_NOCTTY | os.O_NOFOLLOW | os.O_CLOEXEC)
    except OSError:
        raise ValueError('native enrollment requires an attended human terminal; intent retained') from None
    try:
        if not os.isatty(tty) or not stat.S_ISCHR(os.fstat(tty).st_mode):
            raise ValueError('native enrollment requires an attended human terminal')
        measure_error = artifacts / 'measure-diagnostics'
        signature = artifacts / 'userspace-signature.json'
        with _output(signature) as output, _output(measure_error) as diagnostics:
            result = _execute([guard.settings['systemd'] + '/lib/systemd/systemd-measure',
                    'sign', '--current', '--phase=:', '--bank=sha256',
                    '--private-key=' + guard.config['keys']['pcr_private'], '--public-key=' + PUBLIC_KEY],
                    output, -1, timeout=120, stderr=diagnostics)
            output.flush(); os.fsync(output.fileno())
            diagnostics.flush(); os.fsync(diagnostics.fileno())
        if result != 0:
            raise RuntimeError('current-state policy signing failed; no enrollment/retry')
        signature_identity = _read_file(signature, 0o600)
        # Native cryptenroll verifies the current userspace signature by unsealing
        # before slot creation. Require nonempty bounded SHA256 signature input too.
        raw, identity = read_private_blob(signature, limit=65536)
        if identity['sha256'] != signature_identity['sha256']:
            raise ValueError('private current-state signature changed')
        value = json.loads(raw, object_pairs_hook=migration._unique, parse_constant=migration._nonfinite)
        if type(value) is not dict or set(value) != {'sha256'} or type(value['sha256']) is not list or not value['sha256']:
            raise ValueError('unexpected current-state signature banks')
        guard.check('before')
        if _read_file(signature, 0o600) != signature_identity:
            raise ValueError('private current-state signature changed')
        path = artifacts / 'native-diagnostics'
        with _output(path) as diagnostics:
            result = _execute([guard.settings['systemd'] + '/bin/systemd-cryptenroll',
                    *enrollment_arguments(guard.context['before']['prior']['handle'])],
                    diagnostics, tty, timeout=600)
            diagnostics.flush(); os.fsync(diagnostics.fileno())
        migration._sync_directory(artifacts)
        if result != 0:
            raise RuntimeError('native enrollment failed; header outcome uncertain, no retry')
        return {'native_exit': 0, 'signature': signature_identity,
                'diagnostics': _read_file(path, 0o600)}
    finally:
        os.close(tty)
