# Dancer: operation and recovery

ThinkPad X1 Carbon Gen 5, `nixosConfigurations.dancer`, user `roberto`.
Dancer uses stock systemd-boot and **local, attended LUKS unlock**. Tailscale
cannot provide access before the disk is unlocked. `dancer-manual-boot` is a
compatibility alias for the same configuration, not a separate boot policy.

## SSH access

- LAN: `roberto@192.168.68.104`, allowed from `192.168.68.0/22`.
- Kellanved's configured `dancer` alias uses `dancer.tail99ea27.ts.net`;
  `dancer-lan` retains the LAN address. Other homes and deploy-rs retain LAN access.
- Root, password and keyboard-interactive SSH login are disabled. Keep agent
  forwarding disabled and use the approved SSH key.
- Verify new names/addresses against the host key obtained through trusted LAN
  SSH or the console: `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`.
  Never bypass a changed-key warning.

Last recorded follow-up: the Kellanved alias change was published but not
activated or tested through MagicDNS. After the next approved client switch,
check both aliases with fresh connections, not an existing SSH master:

```sh
ssh -o ControlMaster=no -o ControlPath=none dancer-lan hostname
ssh -o ControlMaster=no -o ControlPath=none dancer 'printf "%s\n" "$SSH_CONNECTION"'
```

Before travel, repeat overlay SSH on a cellular hotspot with home Wi-Fi sharing
disabled and the LAN address unreachable. Check the client's actual device-key
expiry. Someone must be available locally to unlock Dancer after a reboot or
power loss.

## GitButler forge authentication over SSH

After deploying the update and starting a fresh user session (for example,
after the next planned reboot), run `unlock-keyring` from a Dancer SSH
terminal. An already running daemon may still be the old version.
If no login keyring exists, choose and confirm a non-empty passphrase (not a
forge token). Otherwise use the existing keyring’s passphrase, which may be
your console login password. Run first-time setup from one session, without
another keyring manager changing the default at the same time.

The helper creates an encrypted login keyring in your persistent home and
sets it as the default if none exists. It leaves an existing default alone;
if you brought your own default, verify that it is password-protected before
running `but config forge auth` from your repo.

SSH key login does not unlock the keyring, and disconnecting SSH does not by
itself relock it. Run `unlock-keyring` again after a reboot or daemon restart.
You do not need to repeat forge authentication unless the saved token expires
or is revoked.

## Updates from Kellanved

Use one reviewed, published commit for prechecks and deployment. Replace the
placeholder below with its full SHA; do not update inputs as part of deployment.
Keep a trusted LAN session and console/passphrase recovery available.

```sh
FLAKE='github:robertodr/phlake-shack/REVIEWED_FULL_COMMIT'

nix build --no-link \
  "$FLAKE#checks.x86_64-linux.deploy-schema" \
  "$FLAKE#checks.x86_64-linux.deploy-rs-eval" \
  "$FLAKE#checks.x86_64-linux.dancer-manual-boot-eval" \
  "$FLAKE#checks.x86_64-linux.dancer-unlock-keyring" \
  "$FLAKE#checks.x86_64-linux.starship-battery-eval" \
  "$FLAKE#checks.x86_64-linux.tailscale-ssh-eval"
```

For firewall, SSH or persistence changes, also run the relevant isolated VM
checks: `ssh-lan-tailscale`, `ssh-lan` and `impermanence`. Their implementation is
in `tests/`; do not replace them with a copied results report. Avoid unrestricted
`nix flake check` as a deployment precheck: it includes full-profile builds/VMs,
and `host-invariants` requires an unavailable private historical baseline.

After review and explicit approval for live maintenance, run interactively:

```sh
nix run "$FLAKE#deploy" -- \
  --checksigs --interactive --skip-checks "$FLAKE#dancer.system"
```

- The only deployment target is Dancer, built remotely on Dancer, reached over
  the literal LAN IP. Home Manager is included in its system profile.
- deploy-rs prompts for sudo and sends it over SSH stdin; never put passwords in
  arguments, logs or configuration. Its interactive/custom-sudo warnings are
  expected. No root SSH, passwordless sudo or agent forwarding is needed.
- `--skip-checks` avoids repeating whole-flake checks after the scoped checks;
  `--checksigs` retains transfer verification. Stop on signature/transfer errors
  rather than weakening daemon trust or using another deployment route.
- `autoRollback` and `magicRollback` protect activation/connectivity, not user
  data or the next boot. Keep ordinary rollback generations and console access.

Activation updates normal bootloader/ESP state but does not reboot. deploy-rs'
NixOS helper removes explicit `default` lines from `loader.conf`; inspect
`bootctl status` / `bootctl list` and the effective next-boot selection before
any separately approved, attended reboot. An unmatched retired EFI entry name
alone is not a reason to clear firmware variables. Do not prune generations or
improvise EFI repairs during an update.

## Tailscale maintenance and recovery

Dancer is a **non-routing endpoint**, tagged `tag:dancer`. NixOS alone owns its
packet filtering: server netfilter mode is `off`, Tailscale SSH is disabled,
and route acceptance/advertisement, exit nodes and kernel forwarding are off.
Kellanved is a user-owned client with normal client netfilter integration, not
the server tag/profile.

The tailnet policy must allow only the intended user to reach `tag:dancer` on
TCP 22, with no overlapping broad grants. Keep policy-editor TCP allow/deny and
UDP-deny tests. A live probe from another identity was not performed; policy
assertions are not evidence of that packet-path test. Do not enroll another
identity or widen grants merely to manufacture a test.

After approved maintenance, verify:

- Firewall, SSH and Tailscale services are healthy. `tailscaled-set` is a boot
  oneshot: inactive/dead after success is normal, and restarting the daemon
  does not rerun it. Check effective preferences rather than its timestamp.
- Both IPv4/IPv6 `nixos-fw` chains enter `dancer-ts-input` first. Only overlay
  SSH, related replies and the intended ICMP handling pass; non-SSH overlay
  ingress and spoofed overlay sources on physical links are blocked.
- No early Tailscale-owned INPUT hook bypasses NixOS filtering; forwarding
  remains zero. Inspect metadata/rules, not private state or full device dumps.
- `/var/lib/tailscale` is backed by encrypted `/persist/var/lib/tailscale`, with
  root ownership, directory mode `0700`, and no group/world-readable state files.
- Fresh LAN and IPv4/IPv6 overlay SSH work. An existing multiplexed connection,
  DNS lookup or `tailscale ping` alone is insufficient.

`dancer-fw-hold` is an independent protective cap during firewall transitions.
A retained cap after stop/failure can intentionally restrict other services.
**Never manually flush or release it**: inspect the lifecycle journal and
restore a reviewed configuration over LAN/console so native verification can
safely release it. Do not turn on Tailscale's automatic hooks or broadly trust
`tailscale0` as a workaround.

If overlay access fails, use independent LAN SSH or the console. Restore a
stopped daemon with `systemctl start tailscaled.service` during approved
maintenance; do not reset/logout/re-enroll an existing node. Service-transition
and fallback tests can interrupt access and require their own maintenance
window. Reboots require someone physically present with the passphrase.

The owner completed IP-based cellular SSH, real firewall/daemon lifecycle,
independent LAN fallback and attended reboot/state-persistence acceptance in
November 2026. That does not guarantee future changes or fix the separately
reported intermittent shutdown hang. No historical boot generation is certified
as recovery merely because it remains listed.

## Reinstallation and boot policy

Routine updates must **not** run Disko, format storage or reprovision credentials.
For a separately approved reinstall, inspect the actual disk by model/capacity
before using `systems/x86_64-linux/dancer/disk-config.nix`: it declares
`/dev/nvme0n1`, a 2 GiB ESP, LUKS2/Btrfs, persistent `/home`, `/nix`, `/persist`,
root rollback and an 8 GiB swapfile. Back up persistent data and recovery
material outside the machine; provision passphrases, account hash and network
credentials privately. Verify manual unlock, local login/sudo, persistence,
swap and SSH host keys before relying on remote access.

The retired Secure Boot/TPM experiment must not be replayed. The manual-LUKS
profile disables TPM/PCR support and retains six defensive service masks.
Firmware updates, firmware key/TPM changes and LUKS header/slot operations are
separate attended maintenance, not installation or documentation cleanup.
fwupd and its EFI helper remain enabled; see the
[package/cache notes](../development/binary-cache.md). Do not clear firmware
keys or TPM state as a troubleshooting shortcut.

After a reinstall only, first establish the restrictive tailnet policy and LAN
recovery. If any Tailscale state already exists, stop and verify ownership rather
than re-enrolling. A genuinely fresh Dancer enrollment uses all safe server
preferences **in the initial command**, not a later corrective `tailscale set`:

```sh
sudo tailscale up --netfilter-mode=off --ssh=false --accept-routes=false \
  --advertise-exit-node=false --advertise-routes= --exit-node= \
  --advertise-tags=tag:dancer
```

Authenticate privately, verify the actual assigned tag and review key expiry.
Do not add `--reset` if the CLI reports unexpected existing preferences.
A fresh travelling Linux client instead uses `sudo tailscale up --ssh=false`
with no server tag or routing; existing clients must not be enrolled again.
Never store enrollment URLs, private keys, auth keys or state in Git/the Nix store.
