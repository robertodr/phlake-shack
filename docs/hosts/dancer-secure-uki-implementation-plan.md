# Dancer Secure UKI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for direct execution, or superpowers:subagent-driven-development only after explicit operator authorization and native-runner preflight. Execute task-by-task with evidence and checkpoints. Complexity does not authorize delegation.

**Goal:** Implement and VM-validate Dancer-only signed UKI boot, then deliver a separately approved manual-unlock Secure Boot stage without enrolling the physical TPM.

**Architecture:** A target-local external NixOS boot installer reads generation Bootspec metadata, constructs and signs systemd-stub UKIs, and publishes verified artifacts before selecting a default. Persistent installer state distinguishes staged images from confirmed successful boots and preserves a known-good closure. Signed-PCR behavior is proved in disposable VMs before any physical enrollment proposal.

**Tech Stack:** Existing pinned NixOS/systemd 260 tooling, Python standard library/unittest, ukify, systemd-measure, sbctl, sbsigntool, encrypted Btrfs/impermanence, NixOS test driver, OVMFFull and swtpm.

**Spec:** `docs/hosts/dancer-secure-uki-design.md` (approved by the owner).

## Global Constraints

- Only Dancer changes. Preserve Framework's configuration and private invariant baseline, input pins, encrypted Btrfs layout, impermanence/root rollback, SSH policy, account identity, projects and other persistent state.
- No reinstall, Disko rerun, repartitioning, TPM clear, unsupported firmware image or Windows workaround on physical hardware.
- Only the human operates Dancer: activation, generation of production keys, firmware settings, key enrollment, TPM enrollment, recovery and reboot. No agent privilege escalation or SSH activation of physical hosts.
- Use standard systemd-stub UKIs; do not enable a second stock or Lanzaboote installer concurrently in production.
- Candidate policy: literal SHA-256 PCR7, signature-authorized SHA-256 PCR11, and literal SHA-256 PCR12 for the expected addon/credential state.
- Retain the independent passphrase slot; no PIN is intended. Never substitute PCR7-only or unrestricted TPM release.
- Previously authorized historical images remain eligible until explicit key rotation/re-enrollment. Menu cleanup is not revocation.
- Private keys: complete `/var/lib/sbctl` database and `/var/lib/secure-uki/pcr-signing`, root-only and encrypted/persistent. Never Git, Nix store, deployment source or bundles.
- TPM firmware remediation remains unresolved. No physical enrollment without functional results and a separate owner risk decision.
- Do not repurpose the owner's 16 GiB flash drive without specific approval.
- deploy-rs adoption itself is a later task; `nh` remains usable. Compatibility requirements must be recorded/tested before adoption, not claimed complete now.
- Work in the existing isolated `feat/dancer-multi-host` worktree. Never initialize GitButler there; its unavailable-project state has an owner-approved Git fallback. Use scoped commits with `Assisted-by: Pi:<current model>`; do not stage private research/evidence accidentally or push without approval.

## Scope and execution checkpoints

This plan covers the shared installer, all Secure Boot/PCR VM feasibility gates,
and preparation of manual-unlock Stage A delivery. It does not authorize that
physical delivery/activation, production key generation, firmware-key enrollment,
TPM enrollment, or deploy-rs installation. Those need owner checkpoints.

**Checkpoint 1 after Task 1:** if the pinned signed-PCR/phase/PCR12 pipeline fails,
stop and revise the design; do not build around it with a weaker policy.

**Checkpoint 2 after Task 7:** present actual results and residual risks before
preparing Stage A delivery. A VM cannot validate the old physical TPM's security.

**Checkpoint 3 after Task 8:** owner reviews delivery/recovery instructions and
explicitly authorizes each human-operated physical stage. TPM enrollment remains
a distinct subsequent maintenance plan.

## Workspace and verification commands

```bash
# Agent-local, unprivileged; no activation.
cd /home/roberto/.pi/agent/worktrees/phlake-shack-dancer
PYTHONPATH=pkgs/secure-uki/src python3 -m unittest discover -s pkgs/secure-uki/tests -v
nix build .#checks.x86_64-linux.secure-uki-unit --no-link
```

Git flake sources include tracked/staged public files, not arbitrary new files.
Stage each task's explicitly listed new public files before Nix checks. Do not
use a whole-tree `path:` export containing private scratch. Use the established
filtered private-check export only for the existing private baseline check,
never for delivered builds. `$PRIVATE_CHECK_SOURCE` below means that freshly
verified local export; keep it off Dancer and out of public artifacts.

All commands inside `machine.succeed(...)` below are **disposable VM guest
commands**, not shell instructions for Framework or Dancer. Test keys/passphrases
are synthetic. Create keys at guest runtime, not as private-key literals in Nix.

Use the existing supported VM lifecycle:

```python
machine.shutdown()
machine.wait_for_shutdown()
machine.start()
machine.wait_for_unit("multi-user.target")
```

Do not use a reboot/crash shortcut to conceal test-driver lifecycle failures.
No actual firmware flash is part of any VM test. If KVM/test tooling is unavailable,
report the blocker; do not request privileges or change the native runner.

## File map and interfaces

| File | Responsibility |
| --- | --- |
| `tests/secure-uki-probe.nix` | Early pinned-tooling encrypted UKI/TPM feasibility gate, no production installer. |
| `tests/secure-uki-vm-helpers.py` | VM-only key creation, Bootspec-based image construction, console recovery and signatures. |
| `pkgs/secure-uki/pyproject.toml`, `default.nix` | Package one standard-library Python executable with pinned tool paths. |
| `pkgs/secure-uki/src/secure_uki/__init__.py`, `metadata.py` | Generation validation, identifiers and typed immutable records. |
| `pkgs/secure-uki/src/secure_uki/prepare.py` | Local UKI assembly, PCR signatures, final UEFI signing and verification. |
| `pkgs/secure-uki/src/secure_uki/publish.py` | Locked/journaled publication, retention, manifest and closure roots. |
| `pkgs/secure-uki/src/secure_uki/cli.py` | Root-only production CLI and boot confirmation; no key creation/enrollment. |
| `pkgs/secure-uki/tests/test_metadata.py`, `test_prepare.py`, `test_publish.py`, `test_cli.py` | Isolated behavioral unit tests using temporary directories and fake command runners. |
| `systems/profiles/boot/secure-uki/default.nix` | Opt-in external installer, persistent state and TPM phase support. |
| `systems/profiles/boot/secure-uki/fwupd.nix` | Matching EFI helper signing, verified before daemon startup. |
| `tests/secure-uki.nix` | Actual production installer, Secure Boot, persistence, failure and rollback tests. |
| `tests/secure-uki-pcr.nix` | Actual initrd unlock, policy mismatch, historical authorization and rotation tests. |
| `systems/x86_64-linux/dancer/default.nix` | Dancer-only module import/opt-in after VM gates. |
| `tests/host-invariants.nix`, `flake.nix` | Assertions and public unit/VM checks, no unrelated dependency changes. |
| `docs/hosts/dancer-secure-uki-operations.md` | Reviewed human-only Stage A procedures, limitations and later enrollment gates. |

Use these shared Python contracts, defined in Task 2, without introducing
parallel implementations:

```python
from dataclasses import dataclass
from pathlib import Path
from collections.abc import Callable, Sequence

Run = Callable[[Sequence[str]], str]  # raises on nonzero exit; never shell=True

@dataclass(frozen=True)
class Generation:
    closure: Path
    kernel: Path
    initrd: Path
    init: Path
    os_release: Path
    cmdline: str
    label: str
    generation_id: str

@dataclass(frozen=True)
class PreparedImage:
    generation: Generation
    path: Path
    image_sha256: str
    pcr_key_fingerprint: str
    entry_id: str  # dancer-<full final image sha256>.efi

@dataclass(frozen=True)
class Tools:
    ukify: Path
    measure: Path
    sbsign: Path
    sbverify: Path
    bootctl: Path
    nix_store: Path

@dataclass(frozen=True)
class Keys:
    db_key: Path
    db_cert: Path
    pcr_private: Path
    pcr_public: Path
```

`read_generation(closure: Path, *, store_root: Path = Path('/nix/store')) -> Generation`
validates Bootspec v1, required regular store files and exactly one supported
profile. The alternative store root exists only for unit fixtures, not a CLI flag.
`prepare_image(generation, destination, tools, keys, run) -> PreparedImage` never
publishes or enrolls. `install(candidate, esp, state_dir, tools, keys, run) -> dict`
returns the committed manifest. `confirm_boot(booted_closure, esp, state_dir, run)
-> dict` updates known-good only after loaded-image and successful-boot checks.
CLI commands are `secure-uki install SYSTEM_CLOSURE` and
`secure-uki confirm-boot`; key/tool/destination paths come from a root-owned Nix
wrapper, not an unrestricted user configuration file.

## Task 1: Prove the pinned UKI and signed-PCR path before production code

**Files:** create `tests/secure-uki-probe.nix`, `tests/secure-uki-vm-helpers.py`;
modify `flake.nix` checks only.

**Consumes:** the pinned packages and existing NixOS VM driver.
**Produces:** check `secure-uki-probe` and helper functions
`make_test_keys(machine, directory)`, `build_guest_uki(machine, closure, directory,
output)`, `recover_at_console(machine)` used by later VM tasks.

- [ ] Read the pinned examples `nixos/tests/systemd-boot.nix` (secureBoot case),
  `systemd-initrd-luks-tpm2.nix`, `systemd-initrd-luks-password.nix`, and
  `nixos/modules/system/boot/systemd/tpm2.nix`. Do NOT copy their unrestricted PCR
  enrollment or dangerous firmware flags into production instructions.
- [ ] Create the disposable VM with a separate encrypted fixture disk and these
  concrete options. Stock systemd-boot is fixture bootstrap only, not a second
  installer in the production module:

```nix
virtualisation = {
  emptyDiskImages = [ 512 ];
  useBootLoader = true;
  useEFIBoot = true;
  useSecureBoot = true;
  efi.OVMF = pkgs.OVMFFull;
  tpm.enable = true;
  mountHostNixStore = true;
};
boot.initrd.systemd = {
  enable = true;
  tpm2.enable = true;
  tpm2.pcrphases.enable = true;
};
systemd.tpm2.pcrphases.enable = true;
```

- [ ] Define runtime VM keys using `sbctl create-keys` and OpenSSL-generated RSA
  PCR signing keys (2048 bits minimum), with root-only guest files. Never call a
  host TPM. Read the guest generation's `boot.json`; pass its exact kernel,
  initrd, `init=` plus kernelParams, and os-release to ukify. Build with
  `--pcr-banks=sha256 --phases=enter-initrd`, the runtime PCR keypair and pinned
  systemd-stub. Finish with sbsign and sbverify. Use no specialisation-in-UKI or
  external command-line override; the fixture's encrypted-root configuration is
  a separate generation/UKI.
- [ ] Add a negative control: trust only VM keys, sign bootmanager but deliberately
  leave the selected UKI unsigned. Require refusal of that image; prevent an
  automatic known-good fallback from masquerading as successful refusal.
- [ ] Run `nix build .#checks.x86_64-linux.secure-uki-probe --no-link -L` and capture
  RED showing the unsigned candidate is not an accepted boot path.
- [ ] Sign the fixture UKI correctly, select its type-2 entry and boot through
  firmware/systemd-boot (not QEMU `-kernel`). Confirm Secure Boot enabled, actual
  systemd-stub UKI boot, the selected generation, and manual console recovery.
- [ ] Validate the enrollment safety check at the live boot phase. systemd v260
  automatically checks a discovered signature against the CURRENT PCR state;
  an initrd-only signature is not presumed valid in late userspace. In the VM,
  generate a root-only enrollment-only signature of the actual current PCR11,
  with no extra phase extension:

```python
# VM ONLY; paths below refer to the guest's synthetic fixture keys.
machine.succeed("umask 077; /run/current-system/systemd/lib/systemd/systemd-measure "
                "sign --current --phase=: --bank=sha256 "
                "--private-key=/var/lib/test-pcr/private.pem "
                "--public-key=/var/lib/test-pcr/public.pem "
                "> /run/enrollment-only.json")
```

  The source `src/measure/measure-tool.c` normalizes `:` to an empty phase without
  selecting default phases. Verify the PIN-free VM enrollment explicitly uses
  that file, `--tpm2-pcrlock=` to disable automatic PCRLock discovery,
  `--tpm2-pcrs=7:sha256+12:sha256`, `--tpm2-public-key-pcrs=11`, and the public key.
  Do not skip the safety check to make tests pass. Remove the enrollment-only
  signature afterward; never embed it in a boot image or export it. Physical
  enrollment instructions are not authorized and must await review of this
  phase-specific maintenance detail.
- [ ] Boot encrypted root through the initrd signature with no keyfile, auto-input,
  passphrase environment, emergency bypass or preopened mapper. Assert mounted
  `/dev/mapper/cryptroot`, no passphrase injection, and cryptsetup success via TPM.
- [ ] Build a UEFI-trusted UKI using the wrong PCR-signing key. Observe the LUKS
  prompt and recover using only the synthetic passphrase:

```python
machine.wait_for_console_text("Please enter passphrase for disk cryptroot")
machine.send_console("vm-recovery-only\n")
machine.wait_for_unit("multi-user.target")
```

- [ ] Test an unexpected signed addon/credential affecting PCR12 while preserving
  the base UKI; require TPM refusal and passphrase recovery. Record actual PCR12
  and initrd phase behavior without assuming zero or leaking raw TPM identity.
- [ ] GREEN must include update and retained-image unlock on one policy. Capture
  commands/versions/results privately. Commit the fixture/check only after this
  works; otherwise stop at Checkpoint 1. Suggested message:
  `test(dancer): prove pinned signed-PCR UKI boot in VMs`.

## Task 2: Package validated generation metadata and immutable identities

**Files:** create `pkgs/secure-uki/pyproject.toml`, `default.nix`,
`src/secure_uki/__init__.py`, `metadata.py`, `cli.py`, `tests/test_metadata.py` beneath
`pkgs/secure-uki`; add `secure-uki-unit` check to `flake.nix`.

**Consumes:** Bootspec v1 field names validated in Task 1.
**Produces:** all dataclasses above and `read_generation`.

- [ ] Write unittest fixtures under a temporary fake store. The fixture writes
  regular kernel/initrd/init/os-release files and Bootspec JSON containing
  `org.nixos.bootspec.v1`, `org.nixos.specialisation.v1 = {}`. Tests check exact
  command line, canonical generation ID, and rejected missing/escaping paths,
  duplicate `init=`, NUL/newline parameters, unknown schema and specialisations.
  Include this complete failure-mode assertion inside the fixture TestCase:

```python
import json
import tempfile
import unittest
from pathlib import Path
from secure_uki.metadata import read_generation

class MetadataTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.store = Path(self.tmp.name) / "store"
        self.closure = self.store / "fixture-system"
        (self.closure / "etc").mkdir(parents=True)
        for name in ("kernel", "initrd", "init"):
            (self.closure / name).write_bytes(b"fixture")
        (self.closure / "etc/os-release").write_text("ID=nixos\n")
        payload = {
            "org.nixos.bootspec.v1": {
                "toplevel": str(self.closure), "system": "x86_64-linux",
                "kernel": str(self.closure / "kernel"),
                "initrd": str(self.closure / "initrd"),
                "init": str(self.closure / "init"),
                "kernelParams": ["console=ttyS0"], "label": "fixture",
            },
            "org.nixos.specialisation.v1": {},
        }
        (self.closure / "boot.json").write_text(json.dumps(payload))

    def test_rejects_path_escape(self):
        payload = json.loads((self.closure / "boot.json").read_text())
        outside = Path(self.tmp.name) / "outside-kernel"
        outside.write_bytes(b"fixture")
        payload["org.nixos.bootspec.v1"]["kernel"] = str(outside)
        (self.closure / "boot.json").write_text(json.dumps(payload))
        with self.assertRaisesRegex(ValueError, "store"):
            read_generation(self.closure, store_root=self.store)
```

- [ ] Run the unittest command from the workspace section for RED. Implement
  metadata parsing with explicit required fields, `Path.resolve(strict=True)`,
  store containment checks and a canonical JSON SHA-256 identity. Require the
  metadata toplevel to match the requested canonical closure; derive os-release
  from that closure, not live `/etc`. Build exactly one `init=<validated init>`
  argument followed by validated kernelParams; do not invoke a shell.
- [ ] Package `secure-uki = secure_uki.cli:main` with Python setuptools and no
  third-party Python runtime dependency. Create the initial CLI as explicitly
  non-operational, so the package does not accidentally report installation success:

```python
def main() -> None:
    raise SystemExit("secure-uki: installation is disabled pending publication support")
```

  Task 4 replaces this guard with the tested real CLI.
- [ ] Run unit GREEN and `nix build .#checks.x86_64-linux.secure-uki-unit --no-link`.
  Confirm no production key reads during evaluation/build. Commit:
  `feat(dancer): validate secure UKI generation metadata`.

## Task 3: Prepare and cryptographically verify images without publication

**Files:** create `prepare.py`, `tests/test_prepare.py` in the package.

**Consumes:** Generation/PreparedImage/Tools/Keys/Run.
**Produces:** `prepare_image(...) -> PreparedImage`.

- [ ] Write a fake runner recording argument arrays and raising on injected errors.
  Test only SHA-256/initrd signatures, embedded nonempty cmdline, public key
  handoff, exact selected generation, wrong/missing keys and verify failure.
  Assert no boot-default, GC or enrollment command occurs during preparation.
- [ ] Run unit RED. Implement staged component files and these argument forms,
  taking Linux/initrd/stub/os-release from validated/pinned sources:

```python
argv = [str(tools.ukify), "build", "--linux=" + str(generation.kernel),
        "--initrd=" + str(generation.initrd),
        "--os-release=@" + str(generation.os_release),
        "--cmdline=@" + str(cmdline_file),
        "--pcr-private-key=" + str(keys.pcr_private),
        "--pcr-public-key=" + str(keys.pcr_public),
        "--pcr-banks=sha256", "--phases=enter-initrd",
        "--output=" + str(unsigned_image)]
run(argv)  # wrapper supplies the pinned stub/search paths established in Task 1
run([str(tools.sbsign), "--key", str(keys.db_key), "--cert", str(keys.db_cert),
     "--output", str(signed_image), str(unsigned_image)])
run([str(tools.sbverify), "--cert", str(keys.db_cert), str(signed_image)])
```

  `cmdline_file`, `unsigned_image` and `signed_image` are regular files in the
  preparation destination, created with restrictive temporary-file modes.
  Verify extracted image sections/PCR signatures using the pinned tooling proved
  in Task 1; matching JSON names or a zero sbsign exit alone is not verification.
  Explicitly validate keypair/certificate consistency before signing. Preserve
  the exact NixOS initrd including any prepended microcode archive; do not strip
  or reorder its contents. Reject an unrecognized split-microcode arrangement
  until Task 1 proves the corresponding ukify inputs.
- [ ] Hash the FINAL image; set `entry_id = 'dancer-' + image_sha256 + '.efi'`.
  Changing policy key/certificate/image must not overwrite an existing identity.
  Never print key bytes or enrollment-only signatures.
- [ ] Run unit GREEN and repeat the actual signed image VM probe through the new
  preparer. Confirm failure leaves the fixture's selected boot entry unchanged.
  Commit: `feat(dancer): prepare locally signed and verified UKIs`.

## Task 4: Locked, journaled publication, retention and boot confirmation

**Files:** create `publish.py`, `tests/test_publish.py`, `tests/test_cli.py`;
modify `cli.py` to replace Task 2's explicit non-operational entrypoint.

**Consumes:** validated generation/preparer contracts.
**Produces:** `install`, `confirm_boot`, real CLI and version-1 manifest.

- [ ] Define manifest JSON with `version: 1`, `default`, `known_good`, `images`
  keyed by entry_id, and a transaction journal with old/default/candidate IDs.
  Each image records closure, SHA-256 and policy-key fingerprint. Reject unknown
  incompatible versions and invalid paths/IDs; preserve compatible extra fields.
- [ ] Write a temporary-ESP test with a confirmed image A, staged B and candidate C.
  Inject each preparation/verification/copy/rename/state failure; assert old default
  and A's closure remain recoverable. Repeated updates without reboot must retain A,
  not bless B or C as known-good. Test lock contention and insufficient peak space.
- [ ] Write event-order tests using an injected fake runner/filesystem operation
  recorder. Expected ordering is explicit:

```python
self.assertLess(events.index("verify"), events.index("publish-image"))
self.assertLess(events.index("pin-closures"), events.index("select-default"))
self.assertLess(events.index("write-journal"), events.index("select-default"))
self.assertLess(events.index("select-default"), events.index("prune"))
self.assertNotIn("enroll", events)
```

- [ ] Run unit RED. Implement one root-owned flock, staging/rename on the ESP,
  flushes, verification before replacement and recoverable signed bootmanager/
  fallback copies. Pin candidate/known-good closures using Nix GC roots before
  selection; reconcile
  interrupted journal/default/manifest states on reapplication, never prune while
  recovery is ambiguous. After success retain candidate plus last confirmed boot.
  Treat default selection as the last boot-selection change, not a promise of
  all-files FAT atomicity. Manage persistent/one-shot EFI default precedence
  explicitly; do not let an old EFI default silently override loader.conf.
- [ ] Implement CLI root guard, actual ESP mount/expected filesystem check,
  encrypted state/key mount ordering, ownership/modes and fixed tool paths.
  Reject store/private-key paths, unsupported initrdSecrets handling,
  specialisations, addons and external credentials rather than silently ignoring
  them. No auto key creation, TPM enrollment, firmware enrollment or flash.
- [ ] `confirm_boot` must match `/run/booted-system`, loaded UKI identity and ready
  system checks before setting known_good; `/run/current-system` or activation
  success alone is insufficient. Fail closed when image identity cannot be verified.
- [ ] Run unit GREEN; kill only the guest installer process at publication boundaries
  in a VM and verify reapplication/rollback recovery using normal VM lifecycle.
  Commit: `feat(dancer): publish recoverable signed UKI generations`.

## Task 5: Opt-in NixOS integration and matching fwupd helper signing

**Files:** create `systems/profiles/boot/secure-uki/default.nix`, `fwupd.nix`;
modify `flake.nix` checks; extend VM tests. Do not enable Dancer yet.

**Consumes:** package CLI and confirmed phase settings.
**Produces:** `boot.secureUki.enable` (default false), `boot.secureUki.bootstrapLabel`
(nullable string), target-local installer and fwupd signing service.

- [ ] Write evaluation assertions for disabled-by-default behavior, no competing
  boot installer, string-only key references, persistent directories, and no
  automatic enrollment/reboot services. Write a VM failing when unsigned/mismatched
  fwupd helper is accepted or the service uses a stale `.signed` marker.
- [ ] Run RED. Implement the opt-in module using the native interface:

```nix
boot.loader.external = {
  enable = true;
  installHook = "${installerWrapper}";
};
boot.loader.systemd-boot.enable = lib.mkForce false;
boot.bootspec.enable = true;
boot.initrd.systemd.tpm2 = {
  enable = true;
  pcrphases.enable = true;
};
systemd.tpm2.pcrphases.enable = true;
environment.persistence."/persist".directories = [
  { directory = "/var/lib/sbctl"; mode = "0700"; }
  { directory = "/var/lib/secure-uki"; mode = "0700"; }
];
```

  `installerWrapper` is a `pkgs.writeShellScript` passing its ONE system-closure
  argument to the packaged CLI with Nix-pinned tools/configuration. Do not embed
  `system.build.uki` in the closure's installer and create a dependency cycle.
  Put all assignments under `lib.mkIf config.boot.secureUki.enable`.
- [ ] Add an opt-in boot-confirmation unit, after successful root unlock, persistence
  mounts and system readiness; run the validated CLI, not `touch known-good`.
- [ ] Sign the selected `config.services.fwupd.package.fwupd-efi` helper into a
  temporary `/run/fwupd-efi` path, verify its certificate and current source,
  then atomically publish the signed sibling before `fwupd.service`. Set the
  daemon's actual EFI-app path/UEFI capsule settings using pinned module/package
  semantics. Preserve the existing C+ rule; no reliance on stale copied bytes.
- [ ] Test first boot, daemon restart, tmpfiles reapply, changed helper input,
  missing keys, failed signature and shutdown/start reconstruction. No real
  helper execution/firmware flash. Re-run existing `fwupd-efi` check unchanged.
- [ ] Run unit/evaluation/VM GREEN and prove disabled module leaves Framework
  unchanged. Commit: `feat(dancer): integrate target-local secure UKI signing`.

## Task 6: Production installer, encrypted persistence and signed-boot recovery VM

**Files:** create `tests/secure-uki.nix`; extend `secure-uki-vm-helpers.py`;
add check `secure-uki` to `flake.nix`.

**Consumes:** real module, package, actual Dancer disk/impermanence modules with
VM-only disk/size overrides as in `tests/impermanence.nix`.
**Produces:** production-path VM evidence, not merely the Task 1 prototype.

- [ ] Create two distinct UKI-aware fixture closures labeled
  `dancer-uki-bootstrap` and `dancer-uki-ready`. Initialize keys only in the guest;
  bootstrap installation fixture may use a test-only no-install initialization
  path, but normal production installer must still reject missing keys.
- [ ] Write RED tests that exercise the actual external install hook and signed
  systemd-boot, not a duplicate test signer. Verify manual passphrase unlocking
  under enabled Secure Boot before any TPM token exists. Test unsigned/tampered
  image refusal without silently booting a different authorized image.
- [ ] GREEN requires selected-image and generation proof, root rollback with
  `/home`, `/persist`, `/nix`, PKI/state/SSH identity intact, header passphrase slot
  retained, and bootable current/known-good closures after collection of unrelated
  fixture store paths. NEVER run broad GC on Framework.
- [ ] Test actual `switch-to-configuration` failure and rollback between two
  UKI-aware installer versions. Capture the stock-installer rollback hazard as
  a negative fixture while Secure Boot is disabled; don't claim an old stock
  profile is safe merely because its kernel was signed later.
- [ ] Restore manual recovery using a trusted signed image or guest-only Secure
  Boot disable procedure. Use synthetic passphrase, never TPM/dbx clearing.
- [ ] Run `nix build .#checks.x86_64-linux.secure-uki --no-link -L`, unit check and
  existing encrypted/SSH checks. Commit only actual GREEN:
  `test(dancer): verify signed UKI persistence and rollback recovery`.

## Task 7: Full signed-PCR acceptance and deliberate revocation VM

**Files:** create `tests/secure-uki-pcr.nix`; extend VM helper tests;
add check `secure-uki-pcr` to `flake.nix`.

**Consumes:** real installer, Task 1 enrollment/phase findings, real initrd and
encrypted layout. **Produces:** candidate-policy acceptance report.

- [ ] Write RED tests proving absent/wrong policy signatures block auto-unlock,
  even if the UKI's UEFI signature is valid. Only synthetic VM enrollment uses
  the explicitly reviewed live-state enrollment signature; remove it afterward.
- [ ] Exercise PCR7+signedPCR11+PCR12, no PIN, no keyfile and no preopened mapper.
  Require unattended encrypted-root boot, routine kernel/initrd update and retained
  image boot. Assert actual signature handoff files in initrd and the expected
  phase ordering before cryptsetup; late-boot signature must NOT be embedded.
- [ ] Negative tests: changed cmdline/initrd with UEFI trust but no approved PCR
  signature; wrong/missing policy key; altered/disabled Secure Boot; signed addon
  and credential extension affecting PCR12. Observe prompt before supplying the
  recovery passphrase and verify success only after manual recovery.
- [ ] Archive a previously signed image; remove it from normal retention and prove
  it still authorizes under the old key. Then VM-only rotate PCR key, authorize
  only retained images, validate replacement enrollment/recovery, retire the old
  TPM token, and prove archived old authorization is refused. Preserve passphrase.
- [ ] Ensure no PCRLock service/policy discovery is used. Inspect actual package
  code/trace evidence to exclude a PolicyAuthorizeNV authorization dependency;
  do not claim modern swtpm perfectly emulates the physical specification1.16 chip.
- [ ] Record storage-root-key/algorithm findings and the physical read-only
  algorithm-check gate. No automatic TPM-generated RSA fallback or TPM clear to
  resolve historical Infineon RSA exposure.
- [ ] Run `nix build .#checks.x86_64-linux.secure-uki-pcr --no-link -L` and all prior
  checks. Commit: `test(dancer): validate signed-PCR UKI unlock and revocation`.
- [ ] Stop at Checkpoint 2: owner sees exact GREEN/RED evidence, limitations,
  enrollment-only signature handling and residual firmware risk before delivery.

## Task 8: Dancer opt-in, regression checks and human-only Stage A delivery

**Files:** modify `systems/x86_64-linux/dancer/default.nix`,
`tests/host-invariants.nix`; create `docs/hosts/dancer-secure-uki-operations.md`.
Use the existing private delivery generator for new sanitized bundle versions;
do not commit it or overwrite prior archives.

**Consumes:** all preceding verified components and owner checkpoint approval.
**Produces:** verified manual-unlock bootstrap/ready bundles and recovery notes.

- [ ] Write invariant RED tests for Dancer-only enablement, external installer,
  disabled stock backend, TPM phase plumbing, key/state persistence and fwupd
  signing service. Preserve all Framework baseline comparisons and original
  root-roolback spelling/order.
- [ ] Enable only Dancer; apply `bootstrapLabel` to the bootstrap source and
  `dancer-uki-ready` to its distinct second source. Never modify the disk layout,
  account passwords, Wi-Fi, SSH restrictions, Docker/Emacs/Pi preferences or
  unrelated lock nodes. These deliveries do not enroll a TPM token.
- [ ] Run these unprivileged checks, with public sources staged correctly:

```bash
nix build .#checks.x86_64-linux.secure-uki-unit --no-link
nix build .#checks.x86_64-linux.secure-uki-probe --no-link
nix build .#checks.x86_64-linux.secure-uki --no-link
nix build .#checks.x86_64-linux.secure-uki-pcr --no-link
nix build .#checks.x86_64-linux.fwupd-efi --no-link
nix build .#checks.x86_64-linux.ssh-lan --no-link
nix build .#checks.x86_64-linux.impermanence --no-link
nix build .#checks.x86_64-linux.pre-commit --no-link
nix build .#nixosConfigurations.dancer.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.kellanved.config.system.build.toplevel --no-link
nix build "path:$PRIVATE_CHECK_SOURCE#checks.x86_64-linux.host-invariants" --no-link
```

  Preserve evidence privately. A private baseline check is not portable public
  CI and must not be made portable by publishing the baseline. If it cannot run,
  report the gate blocked rather than claiming all regressions pass.
- [ ] Generate/bootstrap/ready bundles from sanitized copies only. Verify allowed
  members, sensitive-content exclusion, extraction/checksum/manifest, unchanged
  dependency lock, only-Dancer exports, source/bundle snapshot equality and both
  full closures. Do not deliver the private-check export or Framework credentials.
- [ ] Write a human-only runbook with host labels and explicit approval gates:
  protected backups; attended production key creation/backup; `nh` without sudo
  prefix and explicit `-H dancer`/`path:` source; two distinct UKI-aware system
  profiles and actual boot/rollback validation while Secure Boot remains disabled;
  signature/ESP/helper checks; selected trust anchors preserving dbx; independent
  recovery media/temporary-disable method; then manual-passphrase Secure Boot
  validation. No `--update`, agent forwarding, automated enrollment/reboot or
  instructions to erase the available 16 GiB drive.
- [ ] Add deploy-rs adoption requirements: sanitized closure source, non-root SSH,
  interactive sudo, separate Nix closure signature trust, same install hook,
  UKI-aware auto/magic rollback tests and reboot validation separate from SSH
  confirmation. Do not add a deploy-rs input or claim its integration tested.
- [ ] Commit code/docs with scoped conventional message/trailer; leave private
  archives/research untouched. Stop at Checkpoint 3 and request physical Stage A
  approval. Physical TPM enrollment and actual deploy-rs adoption remain separate.

## Self-review and coverage

- Spec1 scope/constraints: all tasks and Global Constraints; Task8 Dancer-only enablement.
- Spec2 threat model/firmware limits: Task1/7 gates and Task8 runbook, no new security-equivalence claim.
- Spec3 metadata/deep interfaces: Task2/3/4/5, one external backend.
- Spec4 ordering/state/GC/crash limits: Task4/6, no all-files FAT atomicity claim.
- Spec5 keys/policy/revocation: Task1/3/5/7; explicit live-state enrollment verification not published into UKIs.
- Spec6 fwupd: Task5/6, actual selected package/runtime lifecycle, no flashing.
- Spec7 staged migration/recovery: Task6/8, two actual UKI-aware rollback profiles.
- Spec8 deploy-rs: Task8 records the later adoption gate; adoption is deliberately out of scope.
- Spec9 VM/build/privacy gates: Task1/6/7/8, actual behavior and preserved private evidence.
- Spec10 primary evidence: read pinned sources and manuals before each command-sensitive task.

All task code blocks are implementation/test instructions, not code already
installed or evidence that checks passed. Feasibility gaps are stop gates, not
permission to silently narrow the policy or skip enrollment safety verification.

## Execution handoff

1. **Inline execution (recommended here):** parent executes Task1 using
   executing-plans, stops at evidence/checkpoint barriers, and claims no independent
   review. The earlier native-runner issue is not bypassed.
2. **Subagent-driven execution:** requires explicit owner authorization and healthy
   native preflight, then governed workflow/isolation/review. Do not silently
   switch to external/foreground agents if native startup fails.

Review this plan and select execution mode. Neither mode authorizes a physical
activation, TPM operation, firmware setting change or key enrollment.
