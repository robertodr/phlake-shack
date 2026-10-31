# Dancer: permanent attended encrypted boot

`nixosConfigurations.dancer` uses stock systemd-boot and the systemd initrd with
an attended LUKS passphrase. `dancer-manual-boot` is a compatibility alias for the
same system, not an experimental rebuild target. The policy lives in
`systems/profiles/boot/manual-luks/default.nix`.

## Validated deployment

The owner reported booting generation 12, seeing the usual disk-passphrase
prompt, and reaching the desktop normally. The reported `/run/booted-system`
resolved to:

```text
/nix/store/yj00bjqyhyw12y8gcd4fz6fqlq1ia4np-nixos-system-dancer-26.05.20261002.774debe
```

Ordinary generation 11 was retained as rollback during cleanup. These are
bounded human reports, not independent recovery testing, a test of every
rollback generation, or proof of whole-machine integrity.

The abandoned Secure Boot/TPM experiment is retired. Its runtime configuration,
persistence bindings and approved recovery/staging copies were removed. The
inactive package, module, experiment tests and obsolete design/operations docs
are no longer maintained in this tree; Git history retains the old source.
There is no reason to recreate their directories or replay the old procedures.

## Permanent safeguards

- The existing `encrypted` LUKS device uses a passphrase, not an initrd keyfile,
  empty password, TPM token or headless unlock policy. The existing discard
  policy is retained.
- Automatic `systemd-tpm2-setup-early` and `systemd-tpm2-setup` services are masked
  in both initrd and userspace. Userspace also masks `secure-uki-confirm` and
  `secure-uki-fwupd-sign`: six masks remain as defense against old behavior.
  TPM support and PCR phase measurement are disabled in both stages.
- Experimental runtime JSON declarations, package selection and persistent
  `sbctl`/Secure UKI directory bindings are absent. The retained masks do not
  require the removed custom module.
- Existing encrypted filesystems, swap, root-rollback ordering, account/password
  file references, LAN SSH policy and Dancer preferences are preserved.
- fwupd 2.1.6 and its matching runtime EFI helper integration remain enabled.
  Retiring the experiment does not mean removing firmware trust or upgrades.
- No systemd-boot generation-count limit is set. This does **not** disable the
  stock installer's ESP cleanup.

Framework's configuration and all pre-existing input pins remain unchanged. The internal
Dancer base exists only for regression comparisons; the public hostname target
always includes the manual-LUKS policy.

## Updates and remaining boundaries

For upgrades initiated from Framework with builds on Dancer, follow the
[deploy-rs runbook](dancer-deploy-rs.md). It uses a reviewed published source
revision, interactive sudo and activation/connectivity rollback. Its first live
use requires separate approval. The upstream helper also updates bootloader
state and removes explicit systemd-boot `default` lines; review next-boot selection
before any separately approved reboot.

The complete current source in Dancer's ordinary checkout remains available for
human-operated local updates. Publication does not itself update a checkout or
activate a system. Historical installation archives are not current update
sources. Updating existing inputs changes the shared lock and requires separate
review, including the effect on Framework.

Rebuilds, activation, bootloader writes, firmware changes and reboots remain
human-operated maintenance, not automatic consequences of a documentation or
source cleanup. Keep an appropriate ordinary rollback and local-console disk
passphrase access. Do not clear firmware keys or TPM state, mutate live LUKS
headers/slots/keys, prune generations, or reinstall to finish this source cleanup.
Firmware Secure Boot was reported disabled; Nix configuration does not toggle it.

The shutdown hang, Boot0007's ESP helper target, and the old loader-reported
default reference remain separate issues. A successful boot does not establish
that those issues are fixed. The finite cleanup is not a claim that all other
copies have been discovered or physically securely erased.

## Retained regression coverage

The flake keeps checks for manual boot and its six masks, fwupd's EFI helper,
LAN SSH restrictions, impermanence/storage behavior and host invariants, alongside
pre-commit formatting checks. Deployment schema/settings and Dancer-only battery
prompt checks are also available. These cover active functionality, not the retired
experiment. `host-invariants` requires a private local Framework baseline; do not
export that baseline or treat it as a portable public CI fixture. Pre-commit
uses the whole source tree, so do not run it against a dirty/private worktree as
an export shortcut.

See the [installation checklist](dancer-install.md) for separately approved
reinstallation, and the [package/cache notes](../development/binary-cache.md)
for the cached GitButler selections.
