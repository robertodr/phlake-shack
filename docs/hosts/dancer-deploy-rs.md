# Dancer upgrades with deploy-rs

## Scope and current status

The flake configures **Dancer only**: `deploy.nodes.dancer.profiles.system` uses
`nixosConfigurations.dancer`, including integrated Home Manager and the attended
manual-LUKS policy. Framework remains on its existing local update workflow.

Configuration evaluation, deployment-schema validation, generated-script syntax
checks and CLI help inspection have been performed locally. **No deploy-rs live
deployment, remote build, activation or reboot has been tested.** The first live
run requires a separately approved maintenance session with local-console access
and the disk passphrase available.

Dancer's prompt includes its battery icon and percentage beside the time at all
charge levels: red through 10%, yellow through 30%, cyan above 30%. This works in
local and SSH sessions running on Dancer; it does not report Framework's battery.

## Source and targeted prechecks

Use one reviewed, published, immutable source revision for both checks and the
actual deployment. Replace `REVIEWED_FULL_COMMIT` below with that commit's full
SHA; it is a placeholder, not a runnable revision. Do not use an old installation
bundle or the historical dirty/private development worktree.

```bash
FLAKE='github:robertodr/phlake-shack/REVIEWED_FULL_COMMIT'

nix eval --json "$FLAKE#checks.x86_64-linux.deploy-rs-eval.report"
nix eval --json "$FLAKE#checks.x86_64-linux.dancer-manual-boot-eval.report"
nix eval --json "$FLAKE#checks.x86_64-linux.starship-battery-eval.report"
nix build --no-link \
  "$FLAKE#checks.x86_64-linux.deploy-schema" \
  "$FLAKE#checks.x86_64-linux.deploy-rs-eval" \
  "$FLAKE#checks.x86_64-linux.starship-battery-eval"
```

These are scoped configuration/schema checks, not a full regression run or a
proof of hardware, SSH, sudo, rollback or next-boot correctness. The schema check
uses context-free JSON path strings so it does not require building the full
Dancer profile locally; the actual deployment path retains its store context.

Do **not** replace this with an unrestricted `nix flake check` on Framework:
`host-invariants` reads a private Framework baseline, other checks run VMs, and
upstream `deploy-activate` realizes the complete system profile. The whole-tree
pre-commit check is also not a safe dirty/private-source export shortcut. These
checks remain available, but are not part of this local deployment precheck set.

## Live deployment — separate approval required

Only after approving the source, passing the prechecks and approving live
maintenance, run this from an interactive Framework terminal on the existing LAN:

```bash
nix run "$FLAKE#deploy" -- \
  --checksigs --interactive --skip-checks "$FLAKE#dancer.system"
```

- The explicit target is `dancer.system`; no Framework or comparison-base node
  is exported. Home Manager is part of the system, not a separate profile.
- SSH connects to `roberto@192.168.68.104` using existing keys and host-key trust.
  Agent forwarding is explicitly disabled; root SSH and SSH password login stay
  disabled. Do not accept an unexplained changed host key.
- `remoteBuild = true` builds the system on Dancer and uses Dancer's configured
  caches. Framework still evaluates the flake and may transfer source paths and
  derivations; the CLI and small local prechecks run on Framework. This does not
  establish that every transfer will be accepted.
- Activation uses root's ordinary `/nix/var/nix/profiles/system` profile through
  `/run/wrappers/bin/sudo -S -p '' -u`, preserving NixOS's sudo wrapper. deploy-rs
  asks for the sudo password locally and sends it over SSH stdin. Do not put the
  password in configuration, arguments, shell history or logs. Passwordless sudo
  and additional signing/trust exceptions are not required or configured.
- Pinned deploy-rs emits expected warnings that interactive sudo is less secure
  than production SSH-key setups and that custom sudo must accept passwords on
  stdin. The configured command explicitly supports stdin. Those warnings are
  not instructions to enable root SSH, passwordless sudo or agent forwarding.
- `--skip-checks` avoids deploy-rs repeating its unrestricted local whole-flake
  checks **after the explicit scoped prechecks above**. It does not skip the
  deployment confirmation or rollback mechanisms. `--checksigs` retains copy
  signature checking; existing daemon/cache trust policy stays unchanged.

A rejected source/derivation transfer is a blocker, not permission to use
`--no-check-sigs`, change trusted users/keys, sign with an unapproved key, or fall
back to another privilege/cache/deployment route. Stop on unexpected warnings or
errors and review the actual outcome before any retry or recovery action. A dry
activation can still build, copy and execute remotely; it is not a read-only
precheck.

## Rollback and boot boundaries

Both `autoRollback` and `magicRollback` are explicitly enabled. Upstream attempts
rollback after an activation failure and requires remote connectivity
confirmation after activation. These protections do not unlock disks, recover
user data, validate the next boot or fix the separate shutdown hang. Preserve
ordinary rollback generations and console access; do not override either flag
to force a failing deployment through.

The upstream NixOS helper performs `switch-to-configuration switch`. This is live
system maintenance, including normal stock bootloader/ESP updates. Its
[systemd-boot workaround](https://github.com/serokell/deploy-rs/issues/31) also
removes explicit `default` lines from `/boot/loader/loader.conf`; it therefore
**does not preserve explicit next-boot selection**. Review the resulting ordinary
boot entries and effective default during the separately approved first live
session, before considering a reboot. Do not append independent EFI/ESP repair
steps or prune generations.

There is no automatic reboot. Any subsequent reboot is separately approved and
attended: Dancer still needs its usual LUKS passphrase. The six masks, encrypted
storage/persistence, fwupd support and LAN SSH policy remain in effect. The
historical reported generation-12 boot is not evidence that deploy-rs itself has
been exercised.

## Tooling pin

The deploy-rs library is pinned to
`e760371d631165e7d8de5b0dcf148e21ec4c16f0`, matching the source of deploy-rs in the
existing stable nixpkgs pin. A deployment-only overlay uses that cached nixpkgs
package for **both** CLI and target activator. It is not installed as a host-wide
overlay and does not change the cached GitButler selections. Review library and
package compatibility together when changing those pins.

See the [manual-boot policy](dancer-manual-boot-rollback.md),
[installation checklist](dancer-install.md), and
[package/cache notes](../development/binary-cache.md).
