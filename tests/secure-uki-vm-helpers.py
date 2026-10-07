"""Disposable-VM helpers only; never operate on a physical TPM or production keys."""

import json
import re
import shlex

from test_driver.machine import retry as driver_retry


RECOVERY_PASSPHRASE = "vm-recovery-only"


def guest_command(machine, arguments):
    return machine.succeed(shlex.join([str(argument) for argument in arguments]))


def make_test_keys(machine, directory):
    machine.succeed(f"install -d -m 0700 {shlex.quote(directory)}")
    guest_command(machine, ["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt",
                            "rsa_keygen_bits:2048", "-out", f"{directory}/private.pem"])
    guest_command(machine, ["openssl", "pkey", "-in", f"{directory}/private.pem",
                            "-pubout", "-out", f"{directory}/public.pem"])
    guest_command(machine, ["chmod", "0600", f"{directory}/private.pem"])


def build_guest_uki(machine, closure, directory, output, *, sign=True, marker="base",
                    expected_key_mismatch=None):
    """Signed fixtures use the production preparer; unsigned refusal stays raw."""
    if sign:
        script = """
import pathlib,shutil,subprocess,sys
from secure_uki.metadata import Keys,Tools,read_generation
from secure_uki.prepare import prepare_image
closure,directory,output = map(pathlib.Path,sys.argv[1:4])
wrong_public = pathlib.Path(sys.argv[4]) if sys.argv[4] else None
def run(argv):
    return subprocess.run(argv,check=True,capture_output=True,text=True).stdout
tools=Tools(pathlib.Path(shutil.which('ukify')),
            pathlib.Path('/run/current-system/systemd/lib/systemd/systemd-measure'),
            pathlib.Path(shutil.which('sbsign')),pathlib.Path(shutil.which('sbverify')),
            pathlib.Path(shutil.which('bootctl')),pathlib.Path('/unused-nix-store'))
keys=Keys(pathlib.Path('/var/lib/sbctl/keys/db/db.key'),
          pathlib.Path('/var/lib/sbctl/keys/db/db.pem'),directory/'private.pem',
          wrong_public or directory/'public.pem')
try:
    image=prepare_image(read_generation(closure),output.parent,tools,keys,run)
except ValueError as error:
    if wrong_public and 'keypair/certificate does not match' in str(error):
        print('Expected keypair mismatch refused before image construction')
        sys.exit(0)
    raise
if wrong_public:
    raise AssertionError('Wrong public key was not refused')
shutil.copyfile(image.path,output)
shutil.rmtree(image.path.parent)
"""
        guest_command(machine, ["env", f"PYTHONPATH={SECURE_UKI_PYTHONPATH}",
                                "python3", "-c", script, closure, directory, output,
                                expected_key_mismatch or ""] )
        return output
    spec = json.loads(guest_command(machine, [
        "python3", "-c", "import pathlib,sys; print(pathlib.Path(sys.argv[1]).read_text())",
        f"{closure}/boot.json",
    ]))["org.nixos.bootspec.v1"]
    cmdline = " ".join([f"init={spec['init']}", *spec["kernelParams"], f"probe_image={marker}"])
    cmdline_path = f"{directory}/cmdline-{marker}.txt"
    guest_command(machine, ["python3", "-c",
                            "import pathlib,sys; pathlib.Path(sys.argv[1]).write_text(sys.argv[2])",
                            cmdline_path, cmdline])
    unsigned = output + ".unsigned"
    guest_command(machine, [
        "ukify", "build", f"--linux={spec['kernel']}", f"--initrd={spec['initrd']}",
        f"--os-release=@{closure}/etc/os-release", f"--cmdline=@{cmdline_path}",
        "--stub=/run/current-system/systemd/lib/systemd/boot/efi/linuxx64.efi.stub",
        f"--pcr-private-key={directory}/private.pem", f"--pcr-public-key={directory}/public.pem",
        "--pcr-banks=sha256", "--phases=enter-initrd", f"--output={unsigned}",
    ])
    guest_command(machine, ["cp", unsigned, output])
    return output


def select_probe_image(machine, filename):
    """Select a type-2 image, excluding stock fallback entries from the probe menu."""
    machine.succeed("mkdir -p /boot/EFI/Linux /var/lib/probe-stock-entries")
    machine.succeed("find /boot/loader/entries -maxdepth 1 -name '*.conf' "
                    "-exec mv -t /var/lib/probe-stock-entries {} +")
    guest_command(machine, ["python3", "-c",
                            "import pathlib,sys; pathlib.Path('/boot/loader/loader.conf').write_text("
                            "'timeout 3\\neditor no\\ndefault '+sys.argv[1]+'\\n')", filename])
    machine.succeed("bootctl set-default ''; bootctl set-oneshot ''; sync")


def cold_restart(machine):
    machine.shutdown()
    machine.wait_for_shutdown()
    machine.start()


def verify_uki_boot(machine, marker, closure):
    machine.wait_for_unit("multi-user.target", timeout=90)
    status = machine.succeed("bootctl status --no-pager")
    assert "Secure Boot: enabled" in status, status
    assert "systemd-stub" in status, status
    assert machine.succeed("bootctl --print-stub-path").strip().endswith(f"/probe-{marker}.efi")
    assert machine.succeed("readlink -f /run/booted-system").strip() == closure


def recover_at_console(machine):
    # The driver resets the full log on start. Its timeout-enabled queue reader
    # consumes only one line per retry, so inspect the current boot's full log.
    def recovery_prompt(_last_try):
        console = machine.get_console_log()
        console = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", console)
        return "Please enter passphrase for disk cryptroot" in console

    driver_retry(recovery_prompt, 90)
    machine.send_console(RECOVERY_PASSPHRASE + "\n")
    machine.wait_for_unit("multi-user.target", timeout=90)
