# Dancer: attended, manual-unlock Secure Boot

**Preparation document, not activation approval.** Dancer currently remains on
its ordinary boot configuration. Do not execute the physical transition until
Checkpoint 3 is explicitly approved and the release gates below are complete.
Software-TPM/OVMF tests do not establish physical TPM security or compatibility.

## Scope and hard stops

- Target is **Dancer**, never Framework. Operator is the human owner.
- Two distinct sanitized sources: `dancer-uki-bootstrap` and `dancer-uki-ready`.
  These are actual system profiles, not specialisations of a stock profile.
- Manual independent LUKS recovery passphrase at every boot. **No TPM token
  enrollment, provisioning, TPM clear, PIN-free enrollment or firmware update.**
- Both `systemd-tpm2-setup-early` and `systemd-tpm2-setup` are masked in the
  initrd and userspace. PCR measurement remains enabled. A measured/manual boot
  must not automatically create a storage root key or fall back to RSA.
- Agent performs only unprivileged builds, static inspections and disposable VM
  tests. Human alone creates/backups target keys, activates, reboots or changes
  firmware settings. No SSH agent forwarding.
- No Disko rerun, formatting, reinstall, password/Wi-Fi reprovisioning, input
  update or erasure of the available recovery USB. Preserve existing dbx.

## Release gates — all before physical activation

1. Scoped signed commits and full regression evidence, including the private
   Framework invariant check and full host builds; no private evidence exported.
2. Both archive/checksum/manifests verified, Dancer-only host exports, unchanged
   input lock and full closure identity equal to corresponding opt-in source.
   No password hash, production signing keys, recovery material or private checks
   in delivery. Historical archives are not overwritten.
3. First-transition VM proof from a cold, manually unlocked ordinary profile:
   fixed immutable runtime configuration and encrypted state mounts must exist
   **before** the external installer runs. Ordinary `nh os switch` installs the
   bootloader before activation. The tested bridge below supplies only public
   configuration and encrypted mounts, not premature system activation. Missing
   configuration/mounts/keys refuse without changing ESP bytes. Confirmation must
   skip the still-ordinary boot, then verify the actually cold-booted UKI.
4. Human verifies independent recovery passphrase/media, attended console access,
   usable protected backups and sufficient ESP space. No temporary waiver of
   signature verification, filesystem/key guards or installer refusals.
5. Human reviews model-specific firmware key-management procedure. Factory/OEM/
   Microsoft trust and dbx must be inventoried/preserved as agreed. Disposable
   OVMF enrollment commands are **not** physical Lenovo enrollment instructions.
6. Separate explicit Checkpoint 3 approval for the physical manual-unlock rollout.

## Prepared source builds — Dancer, human, unprivileged

After checksum verification and extraction to distinct source directories, build
both sources before changing active profiles. Use explicit path references:

```sh
# Dancer — human, no sudo, no activation
BOOTSTRAP_CLOSURE=$(nix build "path:$BOOTSTRAP_SOURCE#nixosConfigurations.dancer.config.system.build.toplevel" --no-link --print-out-paths)
READY_CLOSURE=$(nix build "path:$READY_SOURCE#nixosConfigurations.dancer.config.system.build.toplevel" --no-link --print-out-paths)
SBCTL=$(nix build "path:$BOOTSTRAP_SOURCE#nixosConfigurations.dancer.pkgs.sbctl" --no-link --print-out-paths)
OPENSSL=$(nix build "path:$BOOTSTRAP_SOURCE#nixosConfigurations.dancer.pkgs.openssl" --no-link --print-out-paths)
```

`BOOTSTRAP_SOURCE` and `READY_SOURCE` must name the two verified extracted
sources. Do not use the full private repository or a private-check export.
Do not use `--update`. Source preparation/building is not key enrollment or
firmware acceptance.

## Attended transition sequence — only after the gates

### A. Prepare protected state while Secure Boot stays disabled

**Dancer — human only.** Inventory the currently booted/active/system-profile
closures, mounted ESP, encrypted mapper, persistence mounts, available ESP space,
EFI entries, trusted firmware variables and LUKS recovery state. Store protected
backups off-host as well as the existing recovery path; never paste private key,
LUKS header/recovery contents or account hashes into chat/issues.

Signing is target-local after manual unlocking. Use separate root-owned,
root-only persistent locations:

- `/var/lib/sbctl` backed by `/persist/var/lib/sbctl`;
- `/var/lib/secure-uki` backed by `/persist/var/lib/secure-uki`;
- db key/certificate: `/var/lib/sbctl/keys/db/db.key` and `db.pem`;
- PCR software signing pair: `/var/lib/secure-uki/pcr-signing/private.pem` and
  `public.pem`.

The db signing pair and stable PCR signing pair are separate. Back them up
securely before the transition. Neither belongs in Git, a Nix derivation/store,
an archive or an agent's workspace. The PCR software RSA signing key is **not**
a TPM-generated RSA storage root key. Do not invoke automatic TPM provisioning.

### Bootstrap bridge and software keys — Dancer, human, only after approval

This sequence is for a **fresh first transition**, with no prior signing state.
Stop on existing keys/nonempty target directories, unexpected symlinks/mounts or
an existing `/etc/secure-uki.json`; inspect/back up instead of hiding, overwriting
or regenerating them. Confirm `/persist` is the mounted Btrfs subvolume of the
active LUKS2 `/dev/mapper/encrypted`, and `/boot` is the actual vfat ESP. Record
these checks privately. Never substitute an unencrypted directory.

```sh
# Dancer — human read-only checks first
findmnt -T /persist -o TARGET,SOURCE,FSTYPE
findmnt -T /boot -o TARGET,SOURCE,FSTYPE
sudo cryptsetup status encrypted
sudo test ! -e /etc/secure-uki.json
sudo test ! -L /etc/secure-uki.json
```

Before the next commands, human must confirm BOTH `/var/lib/sbctl` and
`/var/lib/secure-uki` are absent or empty, not symlinks and not mounted, and the
corresponding persistent directories contain no previous keys/state. Keep this
precondition explicit; do not mount over existing data.

```sh
# Dancer — human, privileged preparation; NO system activation
sudo install -d -m 0700 /persist/var/lib/sbctl /persist/var/lib/secure-uki /var/lib/sbctl /var/lib/secure-uki
sudo mount --bind /persist/var/lib/sbctl /var/lib/sbctl
sudo mount --bind /persist/var/lib/secure-uki /var/lib/secure-uki
sudo ln -s "$BOOTSTRAP_CLOSURE/etc/secure-uki.json" /etc/secure-uki.json
findmnt -T /var/lib/sbctl -o TARGET,SOURCE,FSTYPE
findmnt -T /var/lib/secure-uki -o TARGET,SOURCE,FSTYPE
readlink -f /etc/secure-uki.json
```

Both bind targets must be exact mounted targets backed by the encrypted mapper;
JSON must resolve into the already-built protected bootstrap Nix closure. The
installer independently checks this and rejects unsafe ownership or mounts.
Do not run the closure's `activate` script as a bootstrap shortcut.

After inspecting any sbctl configuration and confirming no existing keys, create
**software/file** keys only. This is not firmware enrollment or TPM provisioning:

```sh
# Dancer — human only. Pin explicit file key backend; never choose TPM key type.
sudo "$SBCTL/bin/sbctl" create-keys --keytype=file
sudo install -d -m 0700 /var/lib/secure-uki/pcr-signing
sudo "$OPENSSL/bin/openssl" genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out /var/lib/secure-uki/pcr-signing/private.pem
sudo chmod 0600 /var/lib/secure-uki/pcr-signing/private.pem
sudo "$OPENSSL/bin/openssl" pkey -in /var/lib/secure-uki/pcr-signing/private.pem -pubout -out /var/lib/secure-uki/pcr-signing/public.pem
sudo chmod 0644 /var/lib/secure-uki/pcr-signing/public.pem
```

Make protected encrypted off-host backups of BOTH signing sets and the existing
recovery material before installing or changing firmware trust. Do not publish
backup contents. The VM uses synthetic keys and a smaller test RSA key; it does
not create or accept production keys on anyone's behalf.

Missing keys/configuration, unencrypted state, unsupported initrd secrets/addons
or insufficient space are stop conditions, not bypass requests. If preparation
fails before activation, preserve any created signing material/backups; don't
clear TPM, wipe directories, unmount blindly or regenerate keys as a remedy.

### B. Establish TWO UKI-aware rollback profiles, Secure Boot still disabled

**Dancer — human only, after bridge and activation approval.** The intended
interfaces are:

```sh
# Dancer — human. Release gate above must be complete first.
nh os switch -H dancer "path:$BOOTSTRAP_SOURCE"
# Attended reboot and manual LUKS unlock; verify actual bootstrap boot.
nh os switch -H dancer "path:$READY_SOURCE"
# Attended reboot and manual LUKS unlock; verify actual ready boot.
```

Run `nh` without a sudo prefix; allow its attended elevation prompt. Never add
`--update` or enable forwarding. Do not script unattended reboot/enrollment.
After each real boot, verify loaded stub/closure identity and successful
`secure-uki-confirm`, not merely `/run/current-system` after activation. Verify
no failed units, persistence/root rollback, SSH access/identity, target-local
signature checks and selected fwupd signed runtime helper reconstruction.

**Never roll back to a pre-bootstrap stock-installer generation.** It can restore
an unsigned systemd-boot manager/fallback, even while signed UKIs still exist.
VM tests reproduce this hazard. Both operational rollback choices must be
UKI-aware, and their signed managers/images/closure roots must remain available.

### C. Enroll selected boot trust and enable Secure Boot, still manual unlock

**Dancer — human only, separately approved firmware action.** Follow the reviewed
model-specific plan, not the VM's blanket `sbctl enroll-keys` command. Preserve
agreed OEM/Microsoft anchors and existing dbx. Have the independent recovery path
and a reviewed temporary-disable method before enabling Secure Boot.

Perform attended cold boots of ready and retained bootstrap. Require manual
LUKS passphrase each time, Secure Boot enabled, exact signed stub/closure and
successful healthy confirmation. Both setup services must remain masked; no
new TPM token or unintended persistent parent may have appeared. Recovery tests
must not clear TPM/dbx, repartition, reinstall or erase recovery storage.

## Routine updates, rollback and recovery

- Continue using the reviewed source and native external installer. Installation
  signs/verifies target-local bytes, publishes signed manager/UKIs, journals state
  and preserves default/last-confirmed closure roots. It never confirms an
  unbooted candidate or enrolls a TPM token.
- Wait for boot confirmation to finish before starting another installer. Shared
  nonblocking locking intentionally refuses concurrent writers.
- Keep candidate/last-confirmed entries and their closures; do not manually prune
  signing state or GC roots. Guest process-kill/GC tests do not prove electrical
  power-loss atomicity across all FAT ESP files.
- On refusal/failure, use the independent passphrase/attended console and verified
  signed recovery artifacts. Restore only after checking expected certificate
  and recorded hash; do not substitute stale `.signed` files or unsigned managers.
- Stable PCR authorization is historical: removal from menu/retention is **not**
  revocation. Rotation/re-enrollment/old-token retirement are separate deliberate
  procedures, not part of these manual-unlock deliveries.

## TPM unattended unlocking remains blocked and separate

Physical Infineon firmware7.61/specification1.16 and the real storage-root-key
algorithm/template remain unresolved. VM ECC does not remove firmware exposure.
Before any provisioning/enrollment, human-approved read-only capability/curve/
parameter/persistent-handle/public-template inspection is required. Existing RSA
or unknown parent is a stop condition. An absent complete ECC template cannot be
proved by read-only capability queries alone; explicit ECC-only provisioning, if
needed, needs a separate human approval. Never enable automatic RSA fallback or
clear TPM to resolve historical Infineon RSA exposure.

Future policy remains literal SHA256 PCR7+12 and signed PCR11 enter-initrd, no PIN,
no PCRLock/PolicyAuthorizeNV substitution, and independent off-host recovery.
Enrollment's temporary live-state userspace signature must satisfy the real
safety check and be removed afterward, never embedded or exported. This document
contains **no physical enrollment approval or command sequence**.

## deploy-rs — requirements only, not adopted

No deploy-rs input or tested integration is added. Future adoption must use a
sanitized source/closure, non-root key-only LAN SSH, interactive sudo, no agent
forwarding, separately agreed Nix closure-signature trust and the same external
install hook. Auto/magic rollback must select only UKI-aware profiles and must be
VM-tested. SSH/connectivity confirmation is not boot/unlock acceptance: reboot,
manual/TPM unlock, loaded closure and retained-image recovery need separate tests.
