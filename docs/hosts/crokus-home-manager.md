# Crokus: standalone Home Manager

## Scope and prerequisites

`homeConfigurations."roberto@crokus"` manages Roberto's terminal/development
home on Apple Silicon (`aarch64-darwin`), with username `roberto`, home
`/Users/roberto`, and initial `home.stateVersion = "26.05"`. It reuses the shared
base and development profiles, not the Linux desktop profile.

Use the existing Nix installation with flakes enabled, as Roberto, from a
reviewed checkout of this repository. Keep an existing working terminal open.
This is **not** a NixOS rebuild or deploy-rs target: never activate it with sudo.
There is no nix-darwin, Homebrew, GUI-application or macOS system-settings
management. GitButler CLI is included; GitButler GUI and kenn-forge are not.
Transitive packages can contain app bundles: upstream Home Manager's Darwin
app/font copy hooks and permission checks still run, and macOS may require App
Management permission. That behavior is not a desktop-management profile.

## Back up before adoption

Before the first switch, make a private, restorable backup outside the checkout
of existing dotfiles and mutable application state. Include shell startup files
(`.profile`, `.zshrc`, `.zprofile`, Bash/Fish configuration as applicable), Git
configuration, `.ssh/config`, relevant `.config` files (including
`ccstatusline/settings.json`), `.pi/agent`, `.claude`, and Herdr/RTK settings and
integration files. Backups may contain credentials: protect them, do not commit
them, and keep them out of the Nix store.

Home Manager checks for conflicting unmanaged files; do not force adoption,
blindly delete conflicts, or overwrite shell files to bootstrap. After building,
compare `result/home-files` with existing files and inspect the generated
`result/activate` script **without executing it**. Deliberately merge or move
only reviewed conflicting files to your backup before switching. If activation
reports another collision, stop and review it rather than adding force flags.
Crokus does not force-overwrite ccstatusline settings. This standalone target
does not inherit the NixOS hosts' automatic `.bak` policy; Home Manager's optional
`-b EXT` is a separate, deliberate collision-backup choice, not a replacement for
application-state backups.

Activation is not limited to installing symlinks. Existing shared hooks:

- merge/replace the configured `statusLine` key in mutable
  `~/.claude/settings.json` while preserving other JSON keys;
- run `herdr integration install pi` and `rtk init --agent pi --global`, modifying
  mutable integration state;
- install `~/.pi/agent/pi-starship.toml` as a mode-600 regular file, replacing its
  contents (Pi-starship rejects symlinks);
- create SSH socket and sops/age directories, in addition to upstream Home
  Manager's normal profile, link, app/font and launch-agent activation.

Managed Pi settings/context/MCP files can also collide with an existing setup.
Generation rollback does **not** promise to undo mutable Pi/Claude/Herdr/RTK
changes, extension downloads, credentials or external application state. Keep
backups even after a successful switch; restore mutable state separately when
needed.

## First native build: pinned bootstrap

The following blocks use **Bash or Zsh**, from the repository root on Crokus.
Resolve Home Manager from this checkout's `flake.lock`, not a floating release,
channel or installer. The selected input currently tracks release 26.05, but the
lockfile revision is authoritative.

```bash
hm_source=$(nix eval --impure --raw --expr '(builtins.getFlake ("path:" + builtins.getEnv "PWD")).inputs.home-manager.outPath')
nix run "$hm_source#home-manager" -- build --flake '.#roberto@crokus'
```

This builds the native home generation and leaves `result` for inspection; it
does not activate the home. A Linux evaluation is not a substitute. Inspect the
build, generated files, activation effects and all conflicts; ensure backups and
signing-key provisioning are ready. Stop on build failure.

**Human-operated activation only, after that review and a successful native
build**, from the same checkout/revision (resolve `hm_source` again if starting a
new session):

```bash
nix run "$hm_source#home-manager" -- switch --flake '.#roberto@crokus'
```

Switch builds as needed and then activates; it is not an inspection-only command.
Do not combine it with the initial build in an unattended bootstrap script.
Record any build, permissions or hook failure before retrying.

## Shell startup and signing

Home Manager installs Fish but does **not** change the macOS login shell or
terminal configuration. After activation, keep the existing shell working. When
session variables are not loaded, manually add a guarded source line to the
appropriate **existing Bash/Zsh startup file**, without replacing its contents:

```bash
if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi
```

Zsh does not read `.profile` automatically; the managed `.profile` alone is not
sufficient for Zsh. The Nix installation's existing shell startup must also keep
its profile binaries on PATH. Open a fresh terminal after editing startup files.
To try the configured Fish without changing the login shell, run:

```bash
"$HOME/.nix-profile/bin/fish"
```

Fish has its own managed session-variable integration; do not source the POSIX
`.sh` file inside Fish. Login-shell selection remains a separate manual choice;
this workflow does not run `chsh` or alter `/etc/shells`.

Git identity is `Roberto Di Remigio Eikås <roberto@totaltrash.xyz>`. Commit and tag
signing remain enabled using **SSH**, not GPG. Separately provision the private
signing key at `~/.ssh/git_signing_ed25519` (`/Users/roberto/.ssh/git_signing_ed25519`)
using your trusted credential workflow, with restrictive filesystem permissions.
Register only its public key as a signing key with the relevant hosting provider;
local signature verification additionally needs an appropriate trusted-signers
setup. There is no assumed Linux 1Password agent path, and the SSH profile does
not automatically add keys to an agent. Do not disable signing to work around a
missing key. Never print/copy private key material into commands, reports, Nix
expressions or the repository. Provision API tokens, authentication and any
sops/age keys separately too; creating a directory does not install secrets.

## Steady-state rebuilds and maintenance

From the reviewed repository root, with `home-manager` now on PATH:

```bash
home-manager build --flake '.#roberto@crokus'
```

Inspect the build and any new conflicts/effects, then explicitly choose:

```bash
home-manager switch --flake '.#roberto@crokus'
home-manager generations
```

`generations` lists retained home generations; it is not a mutable-state backup.
Rebuilding is separate from dependency updates: these commands use the existing
lockfile. Intentionally update inputs only as a separate reviewed change;
`flake.lock` is shared with the Linux hosts, so an update can change their
packages and configurations too. Review its diff and rerun applicable contracts
and Linux regressions before adoption. Do not refresh the lockfile just to switch.

There is no Pi extension-update service/timer on Crokus. After reviewing your
extension sources and backing up mutable Pi state, update them manually:

```bash
pi update --extensions
```

This is networked, mutable extension/package maintenance, independent of the Nix
build. At the pinned Pi version, bare `pi update` updates Pi itself instead; keep
the Nix-managed executable under repository control and use `--extensions` here.

There is no scheduled nh cleanup on Crokus. When space maintenance is needed,
review the pinned CLI help and preview a user-only cleanup first:

```bash
nh clean user --help
nh clean user --keep-since 7d --no-direnv --dry
```

The pinned nh flag is `--dry`, **not** `--dry-run`. Only after reviewing the
preview and retained generations may the owner manually rerun without `--dry`.
That deletes old user generations/roots and can garbage-collect store paths;
rollback options can disappear. Do not run it as part of adoption or use sudo.

## Platform differences

- Exactly these shared Linux packages are omitted: `iputils`, `playerctl`,
  `perf`, `perf-tools`. Other evaluated shared tools were retained; evaluation
  does not guarantee they build or work natively.
- No managed GPG-agent, Pi systemd update service/timer, or nh cleanup scheduler.
  No new launchd replacements were introduced for these omissions. Git uses the
  separately provisioned SSH signing key; Pi updates and cleanup are manual as
  above. Linux service and weekly cleanup policies are unchanged.
- Existing portable-profile behavior **does** include upstream Home Manager
  launchd agents `atuin-daemon` and `tldr-update`. These are not replacements for
  Pi/GPG/nh services. Tealdeer's evaluated systemd definitions are inert on Mac;
  absence of Pi's timer does not mean all launchd/background behavior is absent.
- `xopen` uses macOS `open`, not `xdg-open`. Darwin uses the system `man` default;
  Home Manager man-cache generation is disabled, while portable manpages remain.
- No Linux desktop profile, automatic macOS shell selection, GUI setup or system
  administration is supplied. Terminal preferences, credentials and permissions
  remain human-owned.

## Validation boundary and native acceptance

Development validation on Linux passed all 13 Crokus evaluation contracts and
four focused Linux checks (`crokus-eval`, `starship-battery-eval`,
`agent-skills-eval`, `pi-starship-activation`). The activation derivation evaluates;
that is **not a native Darwin build or activation**. The Pi activation check uses
controlled temporary files, not the real user's home. Linux prompt/timer
regressions also matched their captured baselines.

The repository-wide `pre-commit` check is not green: formatting/deadnix passed,
but verified pre-existing statix warnings remain in `flake.nix` and
`tests/dancer-manual-boot-eval.nix`. `host-invariants` is unavailable because its
ignored historical fixture
`.superpowers/sdd/2026-10-02-multi-host-dancer/kellanved-baseline.json` is missing;
no substitute baseline was fabricated. Those are distinct from the passing
focused checks and do not establish Mac runtime success.

**No native Crokus build or activation has been run during implementation.**
Remaining human acceptance on Apple Silicon:

1. Back up conflicts and mutable state; preserve working shell access.
2. Run the pinned native build above, inspect `result`, and resolve conflicts
   deliberately before switching without sudo.
3. Open a fresh terminal; explicitly start Fish if it is not the login shell.
   Verify session variables/PATH, prompt, Git identity and a signed test commit
   in a disposable repository with the separately provisioned key, SSH host
   configuration, Helix, direnv, Pi and available development tools.
4. Check mutable integrations and existing launchd agents; handle any macOS
   permission prompts deliberately. Record native build/runtime failures and
   versions as follow-up evidence, without secrets.
