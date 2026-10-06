# dancer Stage A installation runbook

This is a human-only handoff for installing the `dancer` NixOS host on the ThinkPad. It is not approval for an agent or script to install, format disks, activate a real machine, enroll TPM, or change firmware. Stop before any destructive step unless the owner is present and explicitly approves the action.

## Current Stage A facts

- Hostname: `dancer`; user: `roberto`; target system: `x86_64-linux`.
- Hardware evidence reviewed for a Lenovo ThinkPad X1 Carbon 5th with Intel CPU and Samsung NVMe. Reconfirm actual hardware at the console before using this runbook.
- Current expected install target: `/dev/nvme0n1`, 476.9 GiB Samsung NVMe.
- Current expected installer USB: `/dev/sda`, 14.5 GiB. Never format `/dev/sda` when it is the live USB.
- Storage layout: GPT; 2 GiB EFI; remaining disk LUKS2/Btrfs; subvolumes `/root`, `/root-blank`, `/home`, `/nix`, `/persist`, `/swap`; 8 GiB swapfile.
- First boot requires a local-console LUKS passphrase. There is no initrd SSH unlock and no TPM auto-unlock in Stage A.
- Production SSH is LAN-only: IPv4 `192.168.68.0/22`; no inbound IPv6 SSH; root, password, and keyboard-interactive login disabled.
- Ethernet is recommended for installation and first checks. Wi-Fi uses NetworkManager profiles that must remain out of Git and out of the Nix store.

## Post-install follow-up configuration

The current repository follow-up excludes Docker (daemon, user group and state
bind mount) and Emacs, and gives Dancer a cyan/blue prompt without the Framework
nickname. Existing `/persist/var/lib/docker` data must not be deleted as part of
the update. Framework retains Docker and its original prompt.

These changes and the [binary-cache fixes](../development/binary-cache.md) are
**not included in the historical V3 archive** described below. Updating the
already-installed host requires a fresh reviewed Dancer-only bundle and a
human-operated rebuild/activation. Do not repeat Disko, formatting, installation
or password/Wi-Fi provisioning for this configuration update.

### Boot activation follow-up (V7)

Dancer disables the shared `updatePiExtensions` activation hook. Previously,
`pi update --extensions` performed mutable network/npm updates at every boot and
blocked console login; the captured journal attributed about 18 seconds to this
step. Framework retains its original hook. Installed extensions are not removed.
Run `pi update --extensions` explicitly as `roberto` after login when updates are
wanted; do not blindly apply npm audit fixes.

V7 includes the V6 EFI-helper correction below. Source/build checks verify that
the generated activation script has no extension-update command, but actual
boot-time improvement must be measured after human-operated activation/reboot.

### Firmware updater follow-up (V6)

Dancer selects fwupd 2.1.6 from the existing pinned unstable input; Framework
continues using stable fwupd. This fixes the JCat catalog entry limit that caused
Lenovo's KEK 2011-to-2023 update to fail with `too many items in array, limit was
100` ([upstream fix](https://github.com/fwupd/fwupd/pull/10479)). No flake input
upgrade or automatic firmware operation is involved.

V5 selected the newer package but missed its runtime EFI integration. V6 also
backports the upstream `C+` tmpfiles rule that populates `/run/fwupd-efi` from the
selected package's matching `fwupd-efi` helper. The rule is Dancer-only, reapplied
at boot/activation, and preserves signed siblings during reapplication. A signed
helper is not provisioned by this rule; Secure Boot signing remains separate.

After human-operated `nh os switch` with the sanitized V6 bundle, check
`fwupdmgr --version` on Dancer: both compile and runtime
`org.freedesktop.fwupd` must show 2.1.6. Also check
`test -s /run/fwupd-efi/fwupdx64.efi` before retrying a firmware update. Do not
manually copy EFI files. The EFI-helper VM test covers first boot, rule
reapplication (including a synthetic signed-sibling preservation marker), and
reboot; it performs no firmware flashing. Firmware operations remain human-only with AC connected. Do not bypass
signature verification or enable Secure Boot before its signed boot chain is
prepared. Firmware changes must be settled before TPM enrollment.

## Prerequisite checklist

On the current laptop:

- [ ] Task 8 `dancer-stage-a-install-only-v3.tar.zst` exists with `dancer-stage-a-install-only-v3-manifest.json` and `dancer-stage-a-install-only-v3.sha256`.
- [ ] The bundle manifest says `nixosConfigurations` exposes only `dancer`; it is a Dancer-only configuration source, not the full two-host repository and not an installer ISO.
- [ ] `flake.lock` in the bundle is byte-identical to the reviewed tree.
- [ ] The bundle excludes `.git`, `.superpowers`, `.direnv`, `result` symlinks, raw Facter/scans/original hardware inputs, Framework personal host/home directories, repo tests/private baselines, logs, diagnostics, all `secrets/` content, `.sops.yaml`, `authinfo.gpg`, credentials, private keys, and unrelated artifacts.
- [ ] The owner has separately approved destructive installation on the ThinkPad.
- [ ] Recovery passphrase storage is ready in a password manager that is not only on the target laptop.

At the ThinkPad live installer local console:

- [ ] Confirm this is the ThinkPad intended to become `dancer`.
- [ ] Confirm network works, preferably over Ethernet.
- [ ] Confirm the reviewed repository tree is present locally on the installer filesystem.
- [ ] Confirm `hostname`/location and identify the target disk by model and capacity before formatting.
- [ ] Confirm `/dev/sda` is the installer USB if it appears with the expected removable capacity; do not target it.

## 1. Transfer the reviewed Dancer-only configuration bundle

Run on the current laptop. Use `dancer-stage-a-install-only-v3.tar.zst`, not the superseded full-source archive, not the v1/v2 Dancer bundles, and not a fresh clone of `HEAD`. The bundle is a normal Nix flake source tree for the Dancer configuration; it is not a bootable installer ISO. Boot the ordinary NixOS live USB separately, then copy and extract this bundle inside the live environment.

The original full repository and Framework configuration remain unchanged in the development worktree. The installation bundle intentionally exposes only `nixosConfigurations.dancer`, omits Framework personal configuration, omits repo-development checks that depend on Git/private baselines, and carries no encrypted secret blobs or private credential files. Publication of the source PR does not make the full repository a credential-free Dancer bundle. Future source updates for this host should still use a newly reviewed Dancer-only bundle rather than copying Framework credential material to `dancer`.

Example transfer over the local network, replacing the address and destination with the live installer's actual values:

```bash
scp dancer-stage-a-install-only-v3.tar.zst nixos@INSTALLER_IP:/tmp/
scp dancer-stage-a-install-only-v3-manifest.json nixos@INSTALLER_IP:/tmp/
scp dancer-stage-a-install-only-v3.sha256 nixos@INSTALLER_IP:/tmp/
```

Run on the ThinkPad live installer:

```bash
cd /tmp
sha256sum -c dancer-stage-a-install-only-v3.sha256
mkdir -p /tmp/phlake-shack-v3
tar --zstd -xf dancer-stage-a-install-only-v3.tar.zst -C /tmp/phlake-shack-v3 --strip-components=1
cd /tmp/phlake-shack-v3
test -f flake.nix
test -f flake.lock
nix --extra-experimental-features 'nix-command flakes' eval --json "path:$PWD#nixosConfigurations" --apply builtins.attrNames
```

The final command must print only `["dancer"]`. Compare the transferred `flake.lock` hash against `dancer-stage-a-install-only-v3-manifest.json` before continuing. Do not clone a public branch as a substitute.

If an earlier v1/v2 bundle was already used to format and mount the target, extract v3 into this new `/tmp/phlake-shack-v3` directory, use this absolute source path for the remaining install command, and keep the existing `/mnt` layout, persistent `roberto` password hash, and copied NetworkManager profile. Do not repeat Disko formatting or credential provisioning just because the source bundle was revised.

## 2. Connect networking in the live installer

Run on the ThinkPad live installer. Ethernet is preferred. For Wi-Fi with NetworkManager:

```bash
nmcli device status
SSID='your-network-name'
sudo nmcli --ask device wifi connect "$SSID"
```

Enter the Wi-Fi password only at the prompt. If the minimal installer lacks the NetworkManager daemon, connect with the installer-provided networking tools first or use the graphical installer. Installing only the `nmcli` client does not start a NetworkManager daemon.

## 3. Identify disks before destruction

Run on the ThinkPad live installer:

```bash
hostname
lsblk -o NAME,PATH,MODEL,SIZE,TYPE,TRAN,RM,MOUNTPOINTS
```

Expected today:

- target: `/dev/nvme0n1`, Samsung NVMe, about 476.9 GiB;
- installer USB: `/dev/sda`, about 14.5 GiB, removable.

If device names, models, removability, or capacities differ, stop and re-identify the target. Do not proceed by guessing. Update `systems/x86_64-linux/dancer/disk-config.nix` only after human review if the real target device is not `/dev/nvme0n1`.

## 4. Inspect the disko script before formatting

Run on the ThinkPad live installer from the extracted v3 bundle directory (`cd /tmp/phlake-shack-v3`, or the actual extraction directory). This human-only dry-run prints/builds the script path only; it does not format by itself.

```bash
cd /tmp/phlake-shack-v3
nix --extra-experimental-features 'nix-command flakes' run --inputs-from "path:$PWD" disko -- --mode destroy,format,mount --dry-run --flake "path:$PWD#dancer"
```

Review the generated script and confirm it targets only the intended internal NVMe disk and mounts under `/mnt`. Do not pass `--yes-wipe-all-disks` on real hardware.

## 5. Create the LUKS passphrase file in installer tmpfs

Run on the ThinkPad live installer only after target-disk confirmation. Keep shell tracing disabled.

```bash
sudo bash -c 'umask 077; read -r -s -p "LUKS passphrase: " pass; printf "\n"; printf "%s" "$pass" > /tmp/secret.key; unset pass'
```

Store the passphrase in a password manager off this laptop before continuing. The next command is destructive.

## 6. Destructive attended format/mount action

Run on the ThinkPad live installer only after the owner explicitly confirms the target disk, model, capacity, and that `/dev/sda` is not the target.

```bash
cd /tmp/phlake-shack-v3
sudo nix --extra-experimental-features 'nix-command flakes' run --inputs-from "path:$PWD" disko -- --mode destroy,format,mount --flake "path:$PWD#dancer"
```

Then create the root-only persistent password directory and generate the account hash interactively:

```bash
sudo install -d -m 700 /mnt/persist/secrets
sudo nix --extra-experimental-features 'nix-command flakes' shell --inputs-from "path:$PWD" nixpkgs#mkpasswd --command bash -c \
  'umask 077; mkpasswd -m yescrypt > /mnt/persist/secrets/roberto-password-hash'
```

No password hash should be displayed, copied to Git, or sent to logs.

## 7. Copy selected NetworkManager profiles

Run on the ThinkPad live installer after `/mnt/persist` exists. Copy only the chosen root-owned connection profile. Do not display file contents and do not copy unrelated credential collections.

```bash
nmcli -f NAME,UUID connection show
sudo ls -l /etc/NetworkManager/system-connections
sudo install -d -m 700 /mnt/persist/etc/NetworkManager/system-connections
# Replace SELECTED_PROFILE.nmconnection with the one reviewed profile file.
sudo install -m 600 /etc/NetworkManager/system-connections/SELECTED_PROFILE.nmconnection \
  /mnt/persist/etc/NetworkManager/system-connections/SELECTED_PROFILE.nmconnection
```

The installed system uses the impermanence bind mount for NetworkManager profiles; these files must be in `/mnt/persist/etc/NetworkManager/system-connections` before first boot if Wi-Fi is required.

## 8. Install NixOS

Run on the ThinkPad live installer from the extracted v3 bundle directory:

```bash
cd /tmp/phlake-shack-v3
findmnt -R /mnt
test -s /mnt/persist/secrets/roberto-password-hash
sudo nixos-install --flake "path:$PWD#dancer" --no-root-passwd
sudo rm -f /tmp/secret.key
```

Skipping a root password is safe only because `roberto` access and sudo are expected to be tested locally before relying on SSH. Copy the extracted Dancer-only bundle to durable storage for later human rebuilds:

```bash
sudo install -d -o 1000 -g 1000 -m 755 /mnt/home/roberto/.config/phlake-shack
sudo rsync -a --delete ./ /mnt/home/roberto/.config/phlake-shack/
sudo chown -R 1000:1000 /mnt/home/roberto/.config/phlake-shack
```

This installed copy is a no-Git Dancer-only source bundle, not a full Framework source checkout and not a place to copy another machine's secrets, SSH keys, SOPS recipients, API tokens, or desktop keyrings.

## 9. Current already-installed V2 target: apply V3 source without reformatting

Use this section only when the target was already formatted/mounted and `nixos-install` was already run from an older bundle. These are human-only commands. Keep the installer SSH session open, do not reboot yet, do not re-run Disko, and do not regenerate or replace the existing LUKS passphrase, persistent `roberto` password hash, or selected NetworkManager profile.

Run on the ThinkPad live installer (`hostname` should be `nixos`) to protect the already-mounted EFI filesystem for the current session:

```bash
findmnt /mnt/boot
sudo mount -o remount,fmask=0077,dmask=0077 /mnt/boot
findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /mnt/boot
sudo stat -c '%U %G %a %n' /mnt/boot /mnt/boot/loader /mnt/boot/loader/random-seed
```

The remounted `/mnt/boot` must be VFAT with `fmask=0077,dmask=0077`; files such as `loader/random-seed` must not be world-readable. Do not print secret file contents.

Run on the current laptop (`hostname` should be `kellanved`) to copy the already built V3 system closure directly to the mounted target store over the live installer's SSH connection. Replace `NEW_SYSTEM` with the reviewed V3 toplevel path from the task evidence, and keep the explicit `nix-command` flag and SSH options:

```bash
NEW_SYSTEM=/nix/store/lbzi3cybr1wi9jz3rcg87fsz8s2zwp2q-nixos-system-dancer-26.05.20261002.774debe
export NIX_SSHOPTS='-o HostName=192.168.68.104 -o User=nixos'
nix --extra-experimental-features 'nix-command flakes' copy \
  --to 'ssh-ng://nixos@192.168.68.104?remote-store=/mnt' \
  "$NEW_SYSTEM"
```

If the live installer requires the legacy SSH store transport instead, use the same target host (`nixos@192.168.68.104`) with a temporary remote helper and `remote-store=/mnt`; do not copy to the Framework host or to the live installer's RAM store by mistake.

Run on the ThinkPad live installer (`hostname` should be `nixos`) to reinstall using the copied V3 system and to update the durable source copy. Keep parent directories owned correctly for `roberto` (UID/GID 1000):

```bash
NEW_SYSTEM=/nix/store/lbzi3cybr1wi9jz3rcg87fsz8s2zwp2q-nixos-system-dancer-26.05.20261002.774debe
cd /tmp/phlake-shack-v3
sudo install -d -o 1000 -g 1000 -m 755 /mnt/home /mnt/home/roberto /mnt/home/roberto/.config /mnt/home/roberto/.config/phlake-shack
sudo rsync -a --delete ./ /mnt/home/roberto/.config/phlake-shack/
sudo chown -R 1000:1000 /mnt/home/roberto/.config/phlake-shack
sudo nixos-install --system "$NEW_SYSTEM" --no-root-passwd --no-channel-copy
sudo rm -f /tmp/secret.key
```

This reinstalls the bootloader/system from V3 while retaining existing `/home`, `/persist`, `/nix`, password hash, Wi-Fi profile, and other data on the mounted target. Remove `/tmp/secret.key` only after the reinstall succeeds.

## 10. First boot and SSH access

Reboot into the installed system only after installation succeeds and `/tmp/secret.key` has been removed. First boot requires local-console LUKS unlock. Fully remote first boot is not configured in Stage A.

At the local console:

```bash
hostname
ip -brief address
```

Use the actual DHCP address until router/DNS resolves `dancer`. Before accepting the host remotely, check the public host fingerprint locally:

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
ssh-keygen -lf /etc/ssh/ssh_host_rsa_key.pub
```

From a LAN client in `192.168.68.0/22`:

```bash
ssh roberto@ACTUAL_DHCP_ADDRESS
```

Offsite SSH requires a suitable LAN jump host; direct non-LAN access is intentionally blocked by policy.

## 11. Read-only post-install checks

Run on the installed `dancer` local console or over an authorized LAN SSH session:

```bash
hostname
findmnt -t btrfs
swapon --show
nmcli connection show --active
sudo sshd -T
sudo iptables -S INPUT
sudo iptables -S nixos-fw
sudo ip6tables -S nixos-fw
systemctl cat systemd-logind
cat /etc/machine-id
```

Expected high-level results:

- hostname is `dancer`;
- Btrfs mounts include `/`, `/home`, `/nix`, `/persist`, and `/.swapvol` as configured;
- swapfile is active;
- NetworkManager has the selected active profile;
- SSH denies root, password, and keyboard-interactive logins;
- TCP/22 is accepted only from `192.168.68.0/22` and rejected otherwise, including inbound IPv6;
- lid close and idle actions are ignored; suspend/hibernate targets are disabled.

Persistence checks:

1. Record public host-key fingerprints only; never copy private key contents.
2. Create and remove a root-only ephemeral marker under `/root` and confirm it disappears across reboot.
3. Create durable markers under `/home/roberto`, `/persist`, and the repository copy, and confirm they survive reboot.
4. Confirm `/etc/machine-id`, SSH host public keys, selected NetworkManager profile metadata, Nix profile/metadata, and project source survive reboot.

Functional checks:

- local console login as `roberto` works;
- `sudo` works for `roberto` after login;
- authorized SSH login works from `192.168.68.0/22`;
- root SSH and password SSH fail;
- lid close, idle, and reboot persistence behave as Stage A expects.

## 12. Git signing key and application logins

Provision the local Git signing key during attended first-boot setup. This key is separate from SSH login authorization and must stay local to `dancer`. Do not copy existing SOPS recipients, service tokens, API credentials, desktop keyrings, or private keys from another machine.

Run as `roberto` on `dancer`:

```bash
printf 'dancer signing test\n' > /tmp/dancer-signing-probe
install -d -m 700 ~/.ssh
ssh-keygen -t ed25519 -f ~/.ssh/git_signing_ed25519 -C 'roberto@dancer git signing'
systemctl --user start ssh-agent
ssh-add ~/.ssh/git_signing_ed25519
ssh-keygen -Y sign -f ~/.ssh/git_signing_ed25519 -n git /tmp/dancer-signing-probe
```

Enter a passphrase when `ssh-keygen` prompts; do not create the production signing key with an empty passphrase. Register only the public key as a GitHub signing key, not as an authentication key:

```bash
cat ~/.ssh/git_signing_ed25519.pub
```

Verify locally with an allowed-signers file:

```bash
printf 'roberto@totaltrash.xyz %s\n' "$(cat ~/.ssh/git_signing_ed25519.pub)" > /tmp/dancer-allowed-signers
ssh-keygen -Y verify -f /tmp/dancer-allowed-signers -I roberto@totaltrash.xyz \
  -n git -s /tmp/dancer-signing-probe.sig < /tmp/dancer-signing-probe
```

After provisioning, check local usability: start `tmux`, confirm `SSH_AUTH_SOCK` points at the user ssh-agent, run `ssh-add -l`, verify shared development commands are available, and create a signed commit in a temporary repository. Before key provisioning or before loading the key into the agent, Git signing is expected to fail clearly because `~/.ssh/git_signing_ed25519` is absent or unavailable.

Application/API logins are separate attended actions. Log in interactively to services as needed; do not depend on Framework desktop keyrings or copied secrets.

## 13. Review gate and stop point

Present the Stage A diffs, Task 7 evidence, this runbook, and the reviewed `dancer-stage-a-install-only-v3` bundle manifest to the owner. Repository implementation approval is not permission to format disks or install. Destructive installation requires a separate attended approval, and Stage B/TPM/Secure Boot work remains gated on attended Stage A hardware acceptance.

Developer note: the original `host-invariants` check uses a private local Framework baseline outside exported archives. Do not include that baseline in the bundle and do not present the Dancer-only bundle as a full two-host repository check. The generated bundle removes those repo-development checks from the copied flake while preserving the reviewed Dancer configuration semantics.
