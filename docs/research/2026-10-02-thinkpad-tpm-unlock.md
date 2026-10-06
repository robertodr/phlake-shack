# Research: TPM unlocking for a headless ThinkPad X1 Carbon Gen 5

**Date:** 2026-10-02
**Scope:** Feasibility and design recommendation only. No host configuration, disk, firmware, or TPM enrollment was changed. The ThinkPad has not been inspected directly.

## Summary

TPM-backed automatic unlocking is a plausible fit for this home-network development host. Lenovo lists a discrete TPM 2.0 for the X1 Carbon Gen 5 platform, but the actual TPM configuration and compatibility must be checked on the laptop. Use LUKS2 underneath Btrfs, retain a recovery passphrase/key, and combine unattended TPM unlocking with a verified/measured boot chain rather than enrolling an unrestricted TPM token.

The current flake already uses LUKS underneath Btrfs, a systemd initrd, and a root rollback service. TPM unlocking can replace the interactive unlock step without changing the filesystem/impermanence model.

## Evidence

### Hardware

Lenovo's [platform specification](https://psref.lenovo.com/syspool/Sys/PDF/ThinkPad/ThinkPad_X1_Carbon_5th_Gen/ThinkPad_X1_Carbon_5th_Gen_Spec.PDF) lists “Discrete TPM 2.0, TCG Certified.” This supports platform-level feasibility, not confirmation that this particular laptop has an enabled, working TPM. The specification was surfaced by web search; direct PDF extraction failed in the research tooling.

### NixOS and the current disk layout

Local files reviewed:

- `systems/x86_64-linux/kellanved/disk-config.nix`: EFI partition plus a LUKS `encrypted` mapping containing Btrfs `/root`, `/nix`, `/home`, `/persist`, and `/swap` subvolumes; an initial read-only `/root-blank` snapshot.
- `systems/x86_64-linux/kellanved/default.nix`: systemd initrd; root rollback after `systemd-cryptsetup@encrypted.service` and before `sysroot.mount`; persistent SSH host keys.
- The working flake's resolved nixpkgs source, `nixos/modules/system/boot/systemd/tpm2.nix`: `boot.initrd.systemd.tpm2.enable`, TPM kernel modules, and initrd TPM userspace support.
- Its `nixos/modules/system/boot/luksroot.nix`: `crypttabExtraOpts` and systemd TPM2 cryptsetup token support. [Upstream module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/system/boot/luksroot.nix).

Use LUKS2 explicitly for the new host rather than assuming the generated header format. Btrfs remains inside the encrypted block device; filesystem-level encryption is not involved. The ThinkPad needs a separately verified disk identifier, swap size, and hardware configuration. Do not copy the Framework's hibernation UUID, resume offset, or 66G swap allocation.

### Enrollment and boot policy

[systemd-cryptenroll's upstream manual source](https://github.com/systemd/systemd/blob/main/man/systemd-cryptenroll.xml) documents:

- TPM2 enrollment for LUKS2 and `tpm2-device=auto` in crypttab.
- Explicit PCR binding with `--tpm2-pcrs=`. Current upstream defaults to no PCR binding when this option is omitted; choose a policy explicitly rather than relying on version-dependent defaults.
- Literal PCR values versus signed PCR policies: literal measurements can change on updates; signed policies can authorize new kernel/initrd measurements without reenrolling each volume.
- A TPM PIN as an optional additional secret. A required boot PIN defeats fully unattended restarts.
- Independent recovery-key enrollment.

A fixed PCR 7 policy checks Secure Boot policy state, not the identity of every boot component. It is less brittle across routine kernel updates, but should not be presented as equivalent to a complete measured boot policy. Binding literal kernel/initrd measurements is stronger in that respect but can require reenrollment after updates.

[Lanzaboote's introduction](https://nix-community.github.io/lanzaboote/) describes NixOS Secure Boot setup, requires an initial UEFI/systemd-boot installation, and explicitly warns about recovery and hardware variability. [Its setup guide](https://nix-community.github.io/lanzaboote/getting-started/prepare-your-system.html) describes host-local signing keys in `/var/lib/sbctl` and signing boot artifacts. [Its firmware guide](https://nix-community.github.io/lanzaboote/getting-started/enable-secure-boot.html) includes ThinkPad instructions and warns not to clear the dbx forbidden-signature database.

Current Lanzaboote documentation also provides [managed measured boot via systemd-pcrlock](https://nix-community.github.io/lanzaboote/how-to-guides/enable-measured-boot.html):

- First check `systemd-pcrlock is-supported` on the actual machine.
- Its baseline policy uses PCRs 0, 4, and 7.
- It updates policy during NixOS rebuilds, rather than requiring manual reenrollment on every kernel change.
- It explicitly calls systemd-pcrlock experimental and requires a recovery passphrase/key.
- The documented current maximum `configurationLimit` is 4, due to policy variant limits.
- On ephemeral root, persist both `boot.lanzaboote.measuredBoot.pcrlockPolicy` and `boot.lanzaboote.measuredBoot.pcrlockDirectory`.

[The explanation](https://nix-community.github.io/lanzaboote/explanation/measured-boot.html) describes PCR 4 coverage of the Lanzaboote stub, which validates the kernel, initrd, and embedded command line. This integration must be verified against the particular Lanzaboote release selected; rolling documentation is not evidence that all older releases include it.

## Recommendation

1. First install the ThinkPad with UEFI boot, LUKS2, Btrfs, impermanence, and a strong manual recovery passphrase. Confirm local boot and LAN-only SSH before adding TPM automation.
2. Keep `/home`, `/nix`, and `/persist` durable. Run the root rollback only after the encrypted volume opens; it does not itself need to alter the TPM enrollment stored in the LUKS header.
3. Add a ThinkPad-only Secure Boot module using a compatible, pinned Lanzaboote release. Keep signing keys root-only in encrypted persistent storage, not in the Git repository or Nix store. Persist the complete signing key/database directory.
4. If hardware and the chosen release support it, trial managed measured boot as the preferred stronger policy. Persist its policy and component state as documented. Disable the enrollment PIN only for the deliberate unattended-boot use case.
5. If managed measured boot is unsupported or insufficiently reliable, stop and choose a fallback explicitly: manual unlocking, a simpler Secure Boot/PCR 7 policy with its narrower guarantees, or a separately designed signed-PCR policy. Do not silently weaken the binding.
6. Enroll only after boot policy is settled and retain an independently usable recovery slot. Back up the recovery secret off the laptop and make a protected LUKS header backup after enrollment; header backups are sensitive.

## Security and operational limits

Unattended unlocking protects a removed drive and, with an appropriate boot policy, helps resist modified boot software. It does not make a stolen intact laptop equivalent to one requiring a secret at boot: it can start its authorized OS and unlock normally. OS authentication, SSH restrictions, patching, and physical security still matter. A discrete TPM also has physical attack considerations; sophisticated invasive attacks are outside this home-server recommendation.

TPM clearing/replacement, motherboard failure, policy changes, firmware updates, and Secure Boot key changes can prevent automatic unlock. Recovery then requires the independent secret and potentially local intervention. Normal rebuilds, retained-generation rollback, and recovery must be tested before assuming unattended availability.

Impermanence is not a backup. Back up projects and irreplaceable persistent data separately.

## Read-only preflight on the ThinkPad

Boot a recent NixOS installer USB in UEFI mode and run:

```sh
bootctl status
systemd-analyze has-tpm2
ls -l /dev/tpm*
```

These inspect availability without enrolling or clearing anything. Secure Boot being disabled initially does not mean it is unsupported. If TPM detection fails, inspect the firmware Security/TPM settings; do not clear the TPM as a diagnostic shortcut, especially if any existing encrypted OS still depends on it.

On an installed NixOS system with the necessary tools, check managed-policy compatibility with:

```sh
sudo /run/current-system/systemd/lib/systemd/systemd-pcrlock is-supported
```

An absent command or missing userspace support is not proof of absent TPM hardware.

## Acceptance checks before unattended use

- Cold boot and restart with no passphrase/PIN prompt; LAN SSH becomes reachable.
- Root rollback happens while development projects, SSH host keys, and policy/signing state survive.
- A kernel/initrd update still auto-unlocks.
- A retained generation still boots and unlocks.
- An intentionally mismatched policy does not auto-unlock; the recovery secret works locally. Schedule this as an attended test with recovery media, not an unplanned firmware reset.
- Test a firmware update only with local access and the recovery secret available.

## Remaining unknowns

Actual TPM firmware/state and PCR policy support; UEFI key enrollment behaviour; RAM and disk capacity; selected Lanzaboote release/API compatibility with this flake; home subnet/IPv6 policy; desired hostname and SSH authorized public key. No final enrollment command should be executed until the real LUKS device and policy are confirmed.
