# Dancer installation checklist

Dancer is already installed. Routine updates must not repeat installation,
Disko, formatting, password provisioning or Wi-Fi provisioning. See the
[current boot/update policy](dancer-manual-boot-rollback.md).

This checklist is for a separately approved, human-attended reinstall. It is
not authorization to run destructive commands. The old Stage A installation
bundles and experiment runbooks are not current installation sources.

## Host and storage

- ThinkPad X1 Carbon 5th generation, `x86_64-linux`; hostname `dancer`, user
  `roberto`. Reconfirm the actual machine and disk before any reinstall.
- The declared internal disk is `/dev/nvme0n1`. Identify it by model and capacity,
  not by device name alone; never format the installer USB.
- `systems/x86_64-linux/dancer/disk-config.nix` defines a 2 GiB EFI partition,
  LUKS2-encrypted Btrfs, persistent `/home`, `/nix` and `/persist`, root rollback,
  and an 8 GiB swapfile. Preserve existing data during ordinary updates.
- Boot uses stock systemd-boot and a local-console disk passphrase. TPM
  auto-unlock and initrd SSH unlock are not configured.

## Before a reinstall

1. Obtain explicit owner approval for the identified target disk and data loss.
2. Establish usable recovery material outside the target machine. Never put
   passphrases, account password hashes, private keys or Wi-Fi credentials in
   Git, the Nix store, terminal output or installation logs.
3. Review current Dancer source and its lock file. If preparing an installation
   bundle, include only reviewed Dancer inputs; exclude Framework personal
   configuration, secrets, private baselines, worktree evidence and credentials.
4. Review the generated Disko plan before executing it. Provision the disk
   passphrase and persistent account hash interactively, without displaying them.
5. Arrange local-console access for first unlock, login and sudo validation.
   Ethernet is preferred; provision only the selected NetworkManager profile.

Repository or PR approval alone does not authorize a reinstall, firmware change,
TPM operation or LUKS header/slot/key change.

## Acceptance checks

After a separately approved installation, verify manual disk unlock, local
`roberto` login and sudo, persistence of `/home`, `/nix` and `/persist`, and active
swap. Confirm the intended root-rollback behavior without deleting persistent
data. Verify public SSH host-key fingerprints locally before accepting them
from another machine.

Production SSH accepts keys for `roberto` only from IPv4 `192.168.68.0/22`;
root, password, keyboard-interactive and inbound IPv6 SSH access are disabled.
There is no direct off-LAN access. Lid close and idle actions are ignored;
suspend and hibernation are disabled.

## Host-specific choices

Dancer excludes Docker and Emacs, uses its own cyan/blue prompt, and updates Pi
extensions manually rather than during activation. These choices do not change
Framework's configuration. Existing persisted Docker data is not a cleanup
candidate merely because Docker is disabled.

Dancer retains fwupd 2.1.6 and its matching `/run/fwupd-efi` helper integration.
The `C+` tmpfiles rule preserves signed siblings; it is not Secure Boot signing
or proof of the firmware boot entry's ESP target. Firmware operations remain
separately approved, human-attended maintenance. See the
[package/cache notes](../development/binary-cache.md).

Provision application logins and any local Git signing key separately. Do not
copy another machine's private keys, desktop keyrings or service credentials.
