# Dancer Secure Boot and signed-PCR unlocking

Date: 2026-10-06
Status: architectural design approved by the owner; implementation planning authorized. Physical rollout and enrollment still require separate approval.

## 1. Decisions and scope

The owner approved designing the next-best path after OEM TPM remediation could
not be verified: Secure Boot first with manual LUKS unlocking, followed by a
separately validated signed-PCR policy on the current TPM. The owner accepted:

- Standard systemd-stub UKIs as the shared foundation for both stages, rather
  than a Lanzaboote/PCRLock boot format followed by a separate migration.
- Separate Secure Boot and PCR-signing private keys, encrypted/persistent and
  root-only on Dancer, never in Git, the Nix store, deployment source or bundles.
- Local signing on Dancer, even if Framework builds the system closure.
- One target-local installer shared by `nh` and eventual deploy-rs activation.
- A stable PCR-signing key for normal updates. Previously authorized historical
  images remain eligible until explicit key rotation/re-enrollment; deleting a
  menu entry, image or system generation is NOT cryptographic revocation.
- Candidate policy: literal SHA-256 PCR7, signature-authorized SHA-256 PCR11,
  and literal SHA-256 PCR12 for the expected addon/credential state.
- Independent passphrase recovery and VM validation before physical enrollment.

Only Dancer changes. Preserve Framework's configuration and private invariant
baseline, input pins, encrypted Btrfs layout, impermanence/root rollback, SSH
policy, account identity, projects and other persistent state. No reinstall,
Disko rerun, repartitioning, TPM clear, unsupported firmware image or Windows
workaround. Deploy-rs adoption itself is a later task; `nh` remains usable.

Agents may evaluate/build and operate approved ephemeral VMs. Only the human
operates Dancer: activation, generation of production keys, firmware settings,
key enrollment, TPM enrollment, recovery and reboot. No agent privilege
escalation or SSH activation of physical hosts.

## 2. Security boundaries

Dancer's specification 1.16 TPM advertises PolicyAuthorize/PolicyPCR/PolicyOR and
SHA-256 but not PolicyAuthorizeNV. Current PCRLock is unavailable. TPM firmware
remediation remains unresolved; signed-PCR authorization does not remediate the
firmware vulnerability. Before production enrollment, the owner must separately
accept the residual risk, including discrete-TPM physical attacks and the known
unremediated firmware, after receiving the functional test results.

Secure Boot verifies executable signatures; TPM policy authorizes release of the
LUKS key for an expected measured environment. No PIN is intended. An intact
stolen laptop can boot an authorized image and unlock normally: login controls,
LAN-only SSH and OS security remain necessary. This is not equivalent to requiring
an off-host secret at every boot or to PCRLock's firmware/bootloader coverage.

The proposed policy does not bind firmware PCR0 or literal boot-image PCR4.
Their absence is deliberate to permit routine boot-image updates without
re-enrollment, not a claim that firmware and every trusted bootloader are
cryptographically pinned. Preserve dbx and review the firmware trust anchors;
retain necessary OEM/Microsoft anchors only through an attended, documented
procedure. Never automatically clear firmware keys, enroll keys or enable
Secure Boot as part of activation.

## 3. One boot installer

The pinned NixOS `boot.uki.settings` / `system.build.uki` provide a UKI construction
primitive, not a complete multi-generation signed installer. The stock
systemd-boot installer runs `extraInstallCommands` after changing boot entries;
a trailing signing command cannot provide the required prepare-before-default
ordering.

Introduce a Dancer-only external boot-install module with one owner of the ESP
and boot defaults. It uses the pinned systemd-stub, ukify, systemd-boot and
signing tools. Do not enable a second stock or Lanzaboote installer concurrently.
No new Lanzaboote input is needed for this chosen architecture.

The installer receives the requested system closure, reads its boot metadata,
and prepares a single-profile UKI with kernel, initrd, microcode as applicable,
and a nonempty embedded command line pointing to that exact closure's init.
No externally supplied kernel/initrd, editor overrides, multi-profile UKIs,
addons or external boot credentials are part of the supported production path.

Assembly and signing run locally after the encrypted persistent storage is
mounted. Refer to generation metadata at runtime rather than making the system
closure depend recursively on a UKI containing that same closure's init path.
Builds contain code and public settings only; do not import private key contents
or private key files through Nix path literals/derivations. Public policy material
and signatures are embedded in the UKI before final UEFI signing.

Deep interfaces:

1. **Generation preparation:** validated metadata and closure in; staged UKI,
   measurement signatures and verification results out. No default selection.
2. **Boot publication:** verified candidate plus retained known-good generation
   in; installed signed artifacts, GC roots, committed manifest and default out.
3. **TPM enrollment:** separate human action using the verified public policy and
   the independent passphrase. Never an activation service.

Reject missing keys, unsafe paths, invalid metadata, missing signing support,
insufficient ESP space and any signature/measurement failure. Serialize installs
with a lock. Resolve retained generations from the committed installer state,
not indiscriminately sign every historical profile. Initially retain the current
candidate and one known-good boot generation, with corresponding closure GC roots.
This space/availability limit does not imply historical-signature revocation.

## 4. Publication and failure ordering

Prepare candidates without changing the currently selected boot generation.
Verify PCR signatures, final UEFI signatures, image contents and generation
references before publication. Use unique immutable generation names, not one
shared UKI filename overwritten on every deployment.

Stage files on the same ESP before rename, flush writes where supported, and
publish the boot default last. Bootloader and fallback executable updates must
also be signed/verified before replacement, retaining a recoverable signed
version. Preserve the old bootable closure and artifacts until the new default
has been published successfully; prune only afterward. Errors propagate to
`switch-to-configuration` so deployment failure/rollback is visible.

This is an ordered, recoverable transaction, not a claim that FAT supports an
atomic transaction across all files or guarantees survival of every power loss.
Test injected failures and document manual recovery for publication interruption.
The candidate's Nix system profile may already have been selected by the caller;
boot-default preservation and caller profile rollback are separate responsibilities.

Persistent state under a root-only `/var/lib/secure-uki`, backed by encrypted
impermanence persistence, records retained closure/image identities and committed
state in a versioned, rollback-compatible manifest. A generation is known-good
only after a confirmed boot into its UKI, successful unlock and working system;
activation success alone is not a boot confirmation. Preserve the last confirmed
boot generation when staging repeated updates without intervening reboots.
TPM unlocking must not depend on reading it before decryption: the needed
public key/signatures are in the boot image and enrollment token, not solely in
`/persist`. GC roots for retained boot closures survive root rollback and prevent
ESP entries referring to garbage-collected init paths.

## 5. Keys and policy lifecycle

Persist the complete Secure Boot key/certificate database at `/var/lib/sbctl`,
not merely one key file, and the separate PCR-signing key under
`/var/lib/secure-uki/pcr-signing`. Back both locations with encrypted persistence.
Use string references to target-local paths,
root-only directories and restrictive file modes. Missing keys fail closed;
activation never silently regenerates them. Human-generated production keys and
sensitive LUKS header backups require protected off-host backups. Do not commit
production key/certificate bundles or unique owner/device identifiers.

Verify the current TPM's relevant algorithms and actual storage-root-key scheme
before enrollment. Advertised commands alone are not a successful sealing test.
In particular, evaluate historical Infineon RSA-generation exposure rather than
silently accepting a TPM-generated RSA storage key on this old firmware. If a
safe usable scheme cannot be established, stop at manual unlocking and return
for a specific risk decision; a different policy is not an automatic fallback.
An ECC storage root, where supported, does not fix other firmware vulnerabilities.

In the signed-PCR stage:

- PCR7 must correspond to the final enabled Secure Boot state/trust database.
- PCR11 authorization covers the selected UKI's measured sections and the
  appropriate initrd phase. Sign only states needed to unlock during initrd,
  not arbitrary late-boot states. Use the embedded public key/signature plumbing
  rather than a signature file obtainable only from the locked filesystem.
- PCR12 binds the expected normal addon/credential-free boot state. Derive and
  verify the real value/measurement behavior; do not assume zero. Confirm that
  this binding actually rejects supported boot-time augmentation mechanisms.

Ordinary updates reuse the policy key and require new signatures, not new LUKS
slots. Trust-database changes may invalidate literal PCR7, and unexpected PCR12
changes may require passphrase recovery. Neither is silently absorbed by
re-enrolling or loosening the policy.

Revocation is an attended maintenance operation: prepare newly authorized
retained images under a new PCR key, establish/test replacement enrollment, then
remove obsolete TPM enrollment material once recovery and the new policy work.
Do not reauthorize all archived images or remove the independent passphrase slot.
No automatic key rotation, TPM-slot deletion or passphrase handling in deploy-rs.

## 6. Firmware updater integration

Retain Dancer's selected fwupd 2.1.6 daemon/client and helper provisioning.
Before enabling Secure Boot, provide target-local signing of the matching fwupd
EFI helper with Dancer's Secure Boot key. Verify against the selected package and
certificate; do not accept a stale `.signed` sibling just because it exists.
Recreate/refresh it on daemon startup after persistent keys are available, because
`/run/fwupd-efi` is volatile and package versions can change. Coordinate with the
existing C+ rule instead of treating copy preservation as signature validation.

Test helper availability and signatures at first boot, daemon restart, tmpfiles
reapplication and reboot. No actual firmware flash is part of VM or agent tests.
Successful helper signing is not proof that any specific future OEM firmware
update is compatible or that TPM remediation has become available.

## 7. Staged physical rollout and recovery

All physical steps are separate, explicitly approved human procedures.

### Stage A: manual-unlock signed boot

1. Confirm backups/passphrase and known-good recovery media remain available.
   Do not repurpose the owner's 16 GiB flash drive without specific approval.
2. Human creates/backups keys; deploy the UKI-aware configuration while Secure
   Boot is still disabled. Boot a signed UKI with manual LUKS unlocking.
3. Establish both a current and a last-known-good rollback system profile with
   the UKI-aware installer. An old stock installer is NOT a safe activation
   rollback target after Secure Boot is enabled: it may reinstall unsigned EFI
   programs. The bootstrap delivery must deliberately establish two distinct
   compatible profiles and test activation rollback, not just two menu entries.
   Use Dancer-only `system.nixos.label` values `dancer-uki-bootstrap` and
   `dancer-uki-ready` to distinguish the two bootstrap configurations without
   changing storage/account state. Both include the needed TPM initrd support,
   but no TPM token is enrolled. Labels are bootstrap metadata, not TPM
   authorization or permission to enable Secure Boot.
4. Verify signed systemd-boot, UKIs and fwupd helper, EFI capacity and boot entries.
5. Human enrolls the chosen trust anchors and enables Secure Boot, preserving
   dbx and required platform certificates. Verify an enabled-Secure-Boot boot
   with the manual passphrase and a retained-generation boot.
6. Validate recovery access. Existing unsigned recovery USB is not assumed to
   boot under Secure Boot: either use verified appropriately signed media or a
   documented local procedure to disable Secure Boot temporarily and unlock with
   the independent passphrase. Never clear the TPM or dbx to perform recovery.

### Stage B: signed-PCR unlock

After VM gates pass, the human separately accepts firmware risk and authorizes
an attended TPM enrollment. Retain the original passphrase slot. Back up the
header sensitively after enrollment. Confirm actual chip enrollment/unseal,
cold boot, reboot, routine update, retained-generation boot, persistent state
and SSH availability. Mismatch must lead to recovery, not relaxed policy.

If any gate fails, keep signed boot with manual unlocking. VM success cannot
establish freedom from bugs/vulnerabilities in the physical IFX TPM.

## 8. Deployment compatibility

`nh` and deploy-rs invoke normal NixOS activation and must reach the same
installer. Build only from the sanitized Dancer export; transfer its closure,
not Framework/private source or signing keys. Future deploy-rs uses non-root
`roberto` SSH, human interactive sudo for system activation, no agent forwarding,
strict host-key verification, and existing LAN-only SSH restrictions. Nix store
closure-signing trust is distinct from Secure Boot/PCR-signing trust and must be
configured separately; never weaken signature checking as a transfer workaround.

Before adopting deploy-rs, test activation success, signing failure, confirmation
failure, its actual auto/magic rollback path, interactive sudo and rollback with
UKI-aware profiles. Its confirmation is an activation/connectivity check, not a
reboot/unlock check. No automatic physical reboot in this design. Additional
boot-path tests remain necessary; retain `nh` as fallback. Adding/pinning deploy-rs
later must not upgrade unrelated inputs.

## 9. Verification and delivery gates

These are required future tests, not results already obtained:

- Unit/fixture checks for validated metadata, unique filenames, retained closure
  selection, private-key exclusion, GC roots and publication ordering.
- Ephemeral UEFI/Secure Boot/swtpm VM: signed boot accepted; unsigned/tampered
  executable refused; ordinary manual passphrase boot/recovery succeeds.
- TPM VM: approved image unlocks without PIN; updated and retained images unlock;
  unauthorized measurements, wrong/missing PCR signature, disabled/changed
  Secure Boot state and unexpected addons/credentials do not auto-unlock.
- Exercise the actual initrd path/signature handoff and supported phases, not
  merely cryptenroll exit status or a package version. No PCRLock dependency or
  PolicyAuthorizeNV authorization path in the chosen implementation.
- Replay of a previously authorized historical image remains permitted by design;
  a separate rotation/re-enrollment test rejects the old authorization afterward.
- Signing/publication failure injection leaves a recoverable previous default;
  clean reboot, installer reapplication and activation rollback preserve it.
  Include repeated updates without reboot and rollback across actual installer
  versions, verifying manifest compatibility and retained known-good state.
- Encryption/root rollback, project/policy/key persistence, closure GC survival,
  Nix metadata and LAN-only SSH regressions, including negative SSH checks.
- fwupd helper runtime tests described above and eventual deploy-rs tests before
  adoption. No actual vendor flash or unsupported VM TPM passthrough.
- Both host builds and existing checks; Framework's private invariant baseline
  remains unchanged and unpublished. Evaluate representative retained closures
  and exact pinned command-line/UKI/PCR interfaces.
- Sanitized generated Dancer delivery passes privacy/member/extraction/hash/lock
  checks and source-vs-bundle configuration equivalence. Private production keys,
  hardware identifiers, credentials and recovery material remain excluded.

If PCR12/phase behavior or another interface is incompatible, report that result
and revise this design with approval. Do not substitute PCR7-only, unrestricted
TPM release, automatic NV/PCRLock enrollment or a weaker boot path.

## 10. Primary references and local evidence

- [systemd v260 systemd-stub](https://github.com/systemd/systemd/blob/v260/man/systemd-stub.xml): UKI sections, PCR11/PCR12, signatures/public key delivery and embedded cmdline behavior.
- [systemd v260 cryptenroll](https://github.com/systemd/systemd/blob/v260/man/systemd-cryptenroll.xml): literal and signature-authorized PCR policies.
- [systemd v260 ukify](https://github.com/systemd/systemd/blob/v260/man/ukify.xml): UKI construction and measurement/signature generation.
- [Lanzaboote measurement explanation](https://nix-community.github.io/lanzaboote/explanation/measured-boot.html): its distinct PCR4/PCRLock model, not the selected installer.
- [deploy-rs README](https://github.com/serokell/deploy-rs/blob/master/README.md): NixOS activation, interactive sudo, auto/magic rollback and separate closure signing.
- [Lenovo advisory PS500721](https://support.lenovo.com/us/en/product_security/ps500721): owner-transcribed fixed-version table/Windows Update delivery; exact Gen5 package remains unverified.
- [Historical Lenovo N1CZT01W README](https://download.lenovo.com/pccbbs/mobiles/n1czt01w.txt): older 7.62 remediation and TPM-information erasure warning, not a current flashing recommendation.
- Local pinned nixpkgs `nixos/modules/system/boot/uki.nix` and
  `nixos/modules/system/boot/loader/systemd-boot/systemd-boot.nix` were read:
  UKI construction exists; post-install commands follow the stock builder.

The owner approved this written spec and authorized implementation planning.
See `dancer-secure-uki-implementation-plan.md` for the staged tasks and gates.
