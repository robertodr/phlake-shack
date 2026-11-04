# Crokus: standalone Home Manager

## Scope and prerequisites

`homeConfigurations."robertoeikas@crokus"` manages Roberto's terminal/development
home on Apple Silicon (`aarch64-darwin`), with username `robertoeikas`, home
`/Users/robertoeikas`, and initial `home.stateVersion = "26.05"`. It reuses the shared
base and development profiles, not the Linux desktop profile.

Use the existing Nix installation, as Roberto, from a reviewed checkout of this
repository. Keep an existing working terminal open. The configuration is bound
to the macOS account `robertoeikas` with home `/Users/robertoeikas`; Home Manager
refuses to activate when `$USER`/`$HOME` differ, so check `echo "$USER $HOME"`
first. The repository's `users/roberto` directory and the Linux hosts' `roberto`
account are unaffected by this Mac-specific account name.
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

A stock macOS Nix installation does not enable the `nix-command` and `flakes`
experimental features, and the `home-manager` script does not enable them for
its internal `nix` calls. After the first activation Crokus manages
`~/.config/nix/nix.conf` itself (`nix.settings.experimental-features`), so for
the bootstrap only, enable them for the current shell session:

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

Repeat this in every new terminal until the first switch has succeeded. Do not
create `~/.config/nix/nix.conf` by hand: it would collide with the managed file.

Resolve Home Manager from this checkout's `flake.lock`, not a floating release,
channel or installer. The selected input currently tracks release 26.05, but the
lockfile revision is authoritative.

```bash
hm_source=$(nix eval --impure --raw --expr '(builtins.getFlake ("git+file://" + builtins.getEnv "PWD")).inputs.home-manager.outPath')
nix run "$hm_source#home-manager" -- build --flake '.#robertoeikas@crokus'
```

Run these as two separate commands (or join them with `&&`). Do **not** write
them as a single `hm_source=$(...) nix run "$hm_source#..."` command: the shell
expands `$hm_source` before the assignment takes effect, so `nix run` would
receive an empty source. `git+file://` resolves the checkout the same way as
`--flake .`, without copying untracked or ignored files into the Nix store.

This builds the native home generation and leaves `result` for inspection; it
does not activate the home. A Linux evaluation is not a substitute. Inspect the
build, generated files, activation effects and all conflicts; ensure backups and
signing-key provisioning are ready. Stop on build failure.

**Human-operated activation only, after that review and a successful native
build**, from the same checkout/revision (in a new session, re-export
`NIX_CONFIG` and resolve `hm_source` again):

```bash
nix run "$hm_source#home-manager" -- switch --flake '.#robertoeikas@crokus'
```

Switch builds as needed and then activates; it is not an inspection-only command.
Do not combine it with the initial build in an unattended bootstrap script.
Record any build, permissions or hook failure before retrying.

## Shell startup and signing

Home Manager installs Fish but does **not** change the macOS login shell
(`/bin/zsh`) or terminal configuration. Instead, like the NixOS hosts bootstrap
Fish from Bash, Crokus manages zsh (`programs.zsh`):

- `~/.zshenv` loads the Home Manager session variables (and `SSH_AUTH_SOCK`,
  below) for every zsh, including non-interactive ones;
- `~/.zshrc` `exec`s the managed Fish (with `--login` for login shells) unless
  zsh was started from Fish or runs a command string (`zsh -c`, `zsh -ic`).

The zsh startup files stay in `$HOME` (`programs.zsh.dotDir`), so the existing,
unmanaged `~/.zprofile` (Homebrew `shellenv`) is still read before `~/.zshrc`.
Do not add `programs.zsh.profileExtra`: that would make `~/.zprofile` managed
and collide with the existing file. The Nix installation's `/etc/zshrc` keeps
the profile binaries on PATH. fish's own macOS login setup rebuilds `PATH` from
`/etc/paths` and pushes the Nix profiles behind `/usr/bin`, so Crokus moves
`~/.nix-profile/bin` and the default profile back to the front in
`programs.fish.loginShellInit`. To get a plain zsh, run `zsh` from Fish. If Fish
is ever broken, open a shell with an explicit command (for example, Terminal's
*Shell ▸ New Command…* `/bin/zsh -f`) and run the `activate` script of a previous
generation listed by `home-manager generations`.
Login-shell selection remains a separate manual choice; this workflow does not
run `chsh` or alter `/etc/shells`. Fish has its own managed session-variable
integration; do not source the POSIX `.sh` file inside Fish.

Git identity is `Roberto Di Remigio Eikås <roberto@totaltrash.xyz>`. Commit and
tag signing remain enabled using **SSH** keys held by **1Password**, as on
kellanved: Crokus imports the shared `ssh/onepassword.nix` and
`git/onepassword.nix` profiles. Git signs with the 1Password-held public key,
`SSH_AUTH_SOCK` points at `~/.1password/agent.sock`, and SSH reads
`~/.ssh/1Password/config` plus the 1Password-specific hosts. On macOS the agent
socket lives at
`~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`; Home Manager
links it to `~/.1password/agent.sock` so the shared paths work unchanged.

In the 1Password app, enable *Settings ▸ Developer ▸ Use the SSH agent* and make
sure the signing key is in a vault the agent serves. 1Password asks for approval
on first use per application. Register the public key as a **signing** key with
the hosting provider. Local verification (`git log --show-signature`) uses the
allowed-signers file that `git/onepassword.nix` generates for that key and sets
as `gpg.ssh.allowedSignersFile`. Signing goes through the agent, so it works
from shells that loaded `SSH_AUTH_SOCK`; GUI applications launched outside a
shell do not inherit it. Do not disable signing to work around a missing agent.
Never print/copy private key material into commands, reports, Nix expressions
or the repository. Provision API tokens, authentication and any sops/age keys
separately too; creating a directory does not install secrets.

## Binary caches

Crokus's managed `~/.config/nix/nix.conf` adds Numtide's cache
(`https://cache.numtide.com`) so the llm-agents tools (GitButler CLI, Claude
Code, Pi, Herdr, RTK, …) are downloaded instead of compiled. With a multi-user
Nix installation the daemon ignores user-supplied substituters unless it trusts
them, and only reads signing keys from its own configuration; the user's
`nix.conf` can grant neither. Once, as an administrator, append to the
root-owned `/etc/nix/nix.conf` (outside Home Manager) and restart the daemon:

```bash
sudo tee -a /etc/nix/nix.conf >/dev/null <<'EOF'
extra-trusted-substituters = https://cache.numtide.com
extra-trusted-public-keys = niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=
EOF
sudo launchctl kickstart -k system/org.nixos.nix-daemon
```

Without this step builds still work, but Nix warns that it is ignoring the
untrusted substituter and compiles those packages locally. A macOS or Nix
reinstall can reset `/etc/nix/nix.conf`; re-check it afterwards.

The managed `nix.conf` only takes effect after the switch that introduces it,
so for that first switch pass the cache explicitly:

```bash
nh home switch --ask --option extra-substituters https://cache.numtide.com
```

## Steady-state rebuilds and maintenance

From the reviewed repository root, with `home-manager` now on PATH (installed by
`programs.home-manager.enable`) and flakes enabled by the managed
`~/.config/nix/nix.conf`:

```bash
home-manager build --flake '.#robertoeikas@crokus'
```

Inspect the build and any new conflicts/effects, then explicitly choose:

```bash
home-manager switch --flake '.#robertoeikas@crokus'
home-manager generations
```

`generations` lists retained home generations; it is not a mutable-state backup.

nh is an equivalent front end. The shared nh profile sets `NH_FLAKE` to the
checkout at `~/phlake-shack` (the same location on every host), and nh picks
`robertoeikas@crokus` from `$USER@hostname`, so this works from any directory
(`--ask` shows the package diff and asks before activating; never use sudo):

```bash
nh home build
nh home switch --ask
```

The variable is part of the Home Manager session variables, so it is only
visible in terminals opened after the switch that introduced it. Do not use
nh's `-u`/`-U` input-update flags here; see the lockfile policy below.

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
  `perf`, `perf-tools`, the VPN clients `openconnect` and `openvpn`, `rclone`,
  and the Emacs spell-checking set (`aspell` with dictionaries, `enchant`,
  `wordnet`). Other evaluated shared tools were retained; evaluation does not
  guarantee they build or work natively.
- No managed GPG-agent, Pi systemd update service/timer, or nh cleanup scheduler.
  No new launchd replacements were introduced for these omissions. Git signs through
  the 1Password SSH agent; Pi updates and cleanup are manual as
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
3. Open a fresh terminal and check that zsh hands over to Fish. Verify session
   variables/PATH, `SSH_AUTH_SOCK`, prompt, Git identity and a signed test
   commit in a disposable repository through the 1Password agent, SSH host
   configuration, Helix, direnv, Pi and available development tools.
4. Check mutable integrations and existing launchd agents; handle any macOS
   permission prompts deliberately. Record native build/runtime failures and
   versions as follow-up evidence, without secrets.
