# Dancer: permanent attended encrypted boot

**Source default: `nixosConfigurations.dancer`.** `dancer-manual-boot` is a
compatibility alias, not a separate policy. Both use
`systems/profiles/boot/manual-luks/default.nix`.

The owner reports reaching the desktop with Secure Boot disabled and the LUKS
passphrase entered manually. Reported booted and running system paths both match:

```text
/nix/store/5if1phb4nif32p3js091s7siqlxli1j0-nixos-system-dancer-26.05.20261002.774debe
```

Old default system generations were subsequently pruned, the stock boot menu
refreshed, and ordinary GC completed by HUMAN success report. These are bounded
reports, not independent hardware, recovery/restore or whole-filesystem proof.
The shutdown hang remains unresolved.

**Updating Dancer's source checkout is a separate step.** Installing a closure
did not update that checkout. Use the complete published configuration commit,
including the manual profile, before returning to ordinary updates. Publication
alone does not update either running system. This document issues no immediate
deployment, reboot, cleanup or key/TPM/LUKS mutation commands.

## Permanent boot policy

The ordinary hostname-selected target:

- Uses stock systemd-boot and the existing systemd initrd, not the custom signed external installer or GRUB.
- Force-disables Secure UKI and issuer/parent/enrollment maintenance flags. Signing and boot confirmation are masked; their runtime configurations/package are absent from the active configuration.
- Disables systemd TPM support and PCR phase measurement in both stages. Both automatic TPM setup services remain explicitly masked in both stages; simply disabling the custom module would otherwise lose those masks.
- Uses the existing `encrypted` LUKS device with no keyfile, empty-password attempt, hardware-token/headless crypttab options or initrd secrets. The rendered crypttab retains the original discard policy and passphrase prompt contract.
- Retains `/var/lib/sbctl` and `/var/lib/secure-uki` as root-owned `0700` persistent directories on the existing boot-critical encrypted Btrfs `/persist`. Retention is not permission to inspect or use their contents.
- Preserves existing filesystems, swap settings, root-rollback ordering, account/password-file references, LAN SSH policy, Dancer preferences and manual Pi-extension-update policy.
- Sets no systemd-boot generation-count limit. **This does not disable the stock installer's ESP cleanup.**

The Framework host definition and input pins are unchanged. Historical Secure
UKI module/package sources are retained as inactive dependencies, not enabled
maintenance features. The internal Dancer base is retained only for storage
comparisons and historical opt-in module tests; it is not exposed as a rebuild target. Ordinary
Dancer now always includes the complete manual profile. Earlier ordinary Dancer
already had Secure UKI disabled, but lacked this profile's retained-state
bindings and TPM masks.

## Routine updates — only after complete source delivery

First deliver the complete configuration, including the new manual profile, to
the ordinary checkout. Git flakes omit untracked files: do not treat a partial
checkout or the old installation bundle as updated source. Source publication
and updating Dancer's checkout are separate from the completed native rollback.
Dependency updates remain a separate maintenance action.

Once that prerequisite is satisfied, the ordinary `.#dancer` target and
hostname-default `nh` selection use the permanent policy. From that checkout,
future HUMAN maintenance can build/install for the next boot with:

```sh
sudo nixos-rebuild boot --flake .#dancer
```

Updating packages additionally requires updating the pinned inputs first, for
example `nix flake update nixpkgs unstable`. That changes the shared lock and
therefore future Framework evaluations too, not its currently running system.
Review such updates separately. The `boot` action writes the system profile and
boot files but does not live-activate or reboot. Keep firmware Secure Boot off;
enter the genuine local LUKS passphrase at the next attended boot. Keep all
recovery pins, backups, signing keys, firmware trust, ECC parent, LUKS slots/tokens
and encrypted persistent secure state. No further cleanup follows automatically.

## Permanent-default source verification

The regression suite now exercises ordinary `dancer`, including conflicting
legacy opt-ins, retained state and all six masks. Its additional alias check
requires both public names to produce the same system derivation. Historical
Secure UKI module/delivery tests use the internal unhardened test base, not an
alternate public experimental host target.

All 28 configuration checks passed. Both public names evaluate to the exact
previously built rollback derivation; the selected public Framework snapshot and
input lock are unchanged. Historical Secure UKI module/delivery assertions also
evaluated to derivations, without executing their build-time/runtime checks.

The source checks are local configuration evaluation, not a new deployment or
independent boot test. The installed rollback above remains the HUMAN-reported
running system; no further rebuild or reboot is needed merely to rename the
source target.

## Historical preparation/build record — superseded operational status

The remaining sections retain the earlier preparation record. Statements below
about missing deployment/boot evidence or future approval prerequisites describe
that earlier stage, not current status or permission to replay completed phases.
Current policy and delivery prerequisite are above.

### What was checked during preparation

`checks.x86_64-linux.dancer-manual-boot-eval.report` evaluates 27 assertions against the real Dancer-derived configuration, including all NixOS assertions, the generated crypttab text, compiled unit-mask definitions, conflicting legacy opt-ins, and rejection on a non-Dancer hostname.

Fresh results:

- 27 configuration assertions passed; substituting ordinary Dancer as a negative control failed on the expected missing target/TPM masks/persistence/guard requirements.
- Existing `secure-uki-module-eval` and `secure-uki-delivery-eval` assertions evaluated successfully to derivations. Their build-time/runtime checks were **not executed**.
- `nixfmt --check` passed for all three changed/new Nix files.
- Pinned deadnix and statix executables were unavailable; neither was installed, repaired or substituted.

Evaluation used a new, retained, tiny PUBLIC input/lock flake that imports repository outputs under offline, impure evaluation. It did not copy the worktree or private baseline into a flake source. Only the explicitly named PUBLIC checks were selected. Full `nix flake check`, pre-commit's whole-tree source export, and the historical private-baseline host check were not run.

Evidence remains on Framework at `/home/roberto/.pi/agent/handoffs/dancer-manual-boot-preparation-v1/`. Initial failures and partial logs are retained. One early test compared whole lazy swap submodules and hit an undefined optional `label`; the corrected test compares resolved device and all non-derived swap settings. This was a test-harness issue, not a live-system failure.

Those preparation results were direct-parent configuration/source checks, not build or native boot proof. The subsequent local build is recorded below; neither stage is independent review, VM/native/physical boot proof, passphrase/recovery validation or evidence of effects on Dancer.

### Replacement built on Framework

The exact rollback derivation built successfully (exit 0, ten local derivations, about six seconds):

```text
/nix/store/5if1phb4nif32p3js091s7siqlxli1j0-nixos-system-dancer-26.05.20261002.774debe
```

All 27 configuration assertions passed freshly before building. Verification of the built PUBLIC artifact confirmed the Dancer hostname/systemd-boot bootspec, all six actual userspace/initrd unit masks, and absence of the four experimental runtime configuration files. Selected PUBLIC configuration/module/test/lock hashes remained unchanged.

The build selected the evaluated derivation directly, not the worktree flake. Remote builders, per-invocation automatic garbage collection and store optimisation were disabled; substitutions were restricted to the existing PUBLIC HTTPS caches. No whole-worktree export, private-baseline check, activation, transport, Dancer access, bootloader write, firmware change or reboot was performed.

Evidence and the Framework-only result link are retained at `/home/roberto/.pi/agent/handoffs/dancer-manual-boot-build-v1/`. Initial reporting-wrapper failures and minimal OWNED reproductions are retained: Nix JSON coercion of an `outPath` attribute set, then whole lazy-submodule serialization forcing the removed `method` option. Only reporting-field selection changed; repository configuration did not.

**This built closure is not deployment readiness.** The boot-file backup attempt stopped; the later five-path metadata run has only a HUMAN success summary without actual output. Both attempts remain consumed/frozen. Neither establishes a valid boot archive, registered fallback roots or safe stock-installer cleanup.

### Historical transition prerequisites — not permission to replay

1. Establish an acceptable current recovery/fallback and preservation basis. Current post-parent preservation/offhost verification is absent; older backups predate that change. No old preservation, delivery, admission or SSH check is reopened by this goal. Do not rerun consumed commands or replace them with fresh-name retries.
2. Review the stock installer's writes, entry regeneration and cleanup against an explicitly preserved fallback. Unlimited generation count alone cannot guarantee preservation of all existing boot entries/files. Actual ESP contents and capacity have not been inspected here. No bootloader installer may be run on the strength of these checks.
3. Approve an exact delivery and installation route and its permitted changes. No transport was performed; SSH authentication remains unconfirmed. Do not repair credentials, run SSH, activate this target or install boot files from this document.
4. Separately approve an attended transition and firmware Secure Boot **disablement only**, with physical-console/recovery arrangements and a passphrase boot check. Preserve firmware keys and TPM state. No live ordering or executable procedure is approved here.

A Nix target does not toggle firmware Secure Boot. With Secure Boot disabled, LUKS still encrypts the disk, but firmware no longer enforces boot-image authenticity. This ordinary boot path must not be assumed bootable while firmware still enforces the custom trust setup. Firmware upgrades already performed remain installed. Do not clear firmware keys/TPM, wipe LUKS tokens/slots, restore headers, repartition, run Disko, reinstall, prune generations or erase old keys/evidence as rollback shortcuts.

The shutdown HANG remains unresolved. This replacement build is not a shutdown fix and grants no power-cycle, USB/power-management change or reboot authority. Stop after the Framework build and artifact verification; leave all existing recovery, keys, parent objects, boot entries, state and evidence intact.
