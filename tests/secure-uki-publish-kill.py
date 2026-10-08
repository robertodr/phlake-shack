"""Guest-only interruption injection; never imported by production code."""
import os
from pathlib import Path
import signal
import sys

from secure_uki import cli, publish

boundary = sys.argv.pop(1)


def die():
    print("KILL_BOUNDARY=" + boundary, flush=True)
    os.kill(os.getpid(), signal.SIGKILL)


original_publish = publish._publish_file


def publication(source, destination, *args, **kwargs):
    original_publish(source, destination, *args, **kwargs)
    path = Path(destination)
    if ((boundary == "image" and path.parent.name == "Linux")
            or (boundary == "primary" and path.name == "systemd-bootx64.efi")):
        die()


publish._publish_file = publication
original_select = publish._select


def selection(*args, **kwargs):
    original_select(*args, **kwargs)
    if boundary == "selection":
        die()


publish._select = selection
original_json = publish._write_json


def state_write(directory, name, value):
    original_json(directory, name, value)
    if boundary == "manifest" and name == "manifest.json":
        die()


publish._write_json = state_write
cli.main(sys.argv[1:])
