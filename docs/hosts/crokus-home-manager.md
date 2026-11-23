# Crokus: standalone Home Manager

Apple Silicon Mac, account `robertoeikas`, home `/Users/robertoeikas`, target
`homeConfigurations."robertoeikas@crokus"`. This manages terminal/development
configuration, not macOS system settings, Homebrew or the Linux desktop.
**Run as that user, never with sudo.** A Linux evaluation is not a native Mac
build or an activation test.

## Routine updates

From a reviewed checkout, build first and inspect changes/conflicts before
switching. Use the existing lockfile; input updates are separate reviewed
changes shared with the Linux hosts.

```sh
home-manager build --flake '.#robertoeikas@crokus'
home-manager switch --flake '.#robertoeikas@crokus'
home-manager generations
```

With `NH_FLAKE` pointing to `~/phlake-shack`, the equivalent commands from any
directory are `nh home build` and `nh home switch --ask`. Session-variable changes
require a fresh terminal. Do not add nh's input-update flags just to rebuild.

To roll back, select a retained generation from `home-manager generations` and
run its `activate` script. Rollback does not restore mutable application state.

## First adoption or recovery bootstrap

Back up existing shell/Git/SSH/config files and mutable `.pi/agent`, `.claude`,
Herdr and RTK state privately outside the checkout. Keep a working terminal open.
Home Manager refuses conflicting unmanaged files: compare `result/home-files`
and inspect `result/activate`, then deliberately merge/move conflicts. Do not
force adoption or delete files blindly. This target has no automatic `.bak`
policy; optional collision backups are not application-state backups.

Before the first activation, flakes may need enabling for this shell only.
Use Bash/Zsh from the repository root and resolve Home Manager from its lockfile:

```sh
export NIX_CONFIG="experimental-features = nix-command flakes"
hm_source=$(nix eval --impure --raw --expr '(builtins.getFlake ("git+file://" + builtins.getEnv "PWD")).inputs.home-manager.outPath')
nix run "$hm_source#home-manager" -- build --flake '.#robertoeikas@crokus'
```

After a successful **native build**, inspection, backups and conflict resolution:

```sh
nix run "$hm_source#home-manager" -- switch --flake '.#robertoeikas@crokus'
```

Do not create `~/.config/nix/nix.conf` manually during bootstrap: activation
manages it. Re-export `NIX_CONFIG` and resolve `hm_source` in any new terminal
until the first switch succeeds. Native app/font hooks can require macOS App
Management permission; stop and resolve permission failures deliberately.

Activation also changes mutable state: Claude's `statusLine` setting, Herdr/RTK
Pi integrations, and Pi-starship's mode-600 regular config file. Other managed
Pi files can collide with an existing setup. Keep backups for these effects,
extension downloads and credentials; generation rollback alone is insufficient.

## Shell and signing recovery

The macOS login shell stays zsh. Managed `.zshenv` loads session variables;
`.zshrc` hands interactive sessions to Fish, except when launched from Fish or
with a zsh command string. Existing `.zprofile` remains unmanaged, including
Homebrew setup. Do not add a managed replacement without reviewing conflicts.
Fish's login setup puts Nix profiles back ahead of system paths.

For plain zsh, start `zsh` from Fish. If Fish startup breaks, open Terminal's
*Shell ▸ New Command…* with `/bin/zsh -f`, then activate a retained generation.
Do not run `chsh` or edit `/etc/shells` as a rebuild workaround.

SSH and Git SSH-signing use 1Password. Enable its SSH agent and make the key
available in a served vault; register the public key as a signing key with the
forge. Home Manager links the macOS agent socket to `~/.1password/agent.sock`;
new shell sessions load `SSH_AUTH_SOCK`. GUI apps may not inherit that environment.
Do not disable signing to hide an agent failure. Provision API tokens, sops/age
keys and application logins separately; never copy private keys into the store.

## Binary cache trust

The managed user config adds `https://cache.numtide.com`, but a multi-user Nix
daemon must separately trust the substituter and signing key. Once, as an
administrator, add any missing settings to `/etc/nix/nix.conf` and restart it:

```text
extra-trusted-substituters = https://cache.numtide.com
extra-trusted-public-keys = niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=
```

```sh
sudo launchctl kickstart -k system/org.nixos.nix-daemon
```

This administrator step is separate from Home Manager activation. Without it,
Nix may ignore the cache and compile locally. Recheck after a macOS/Nix reinstall.
For the switch first introducing the user cache config, pass the cache explicitly:

```sh
nh home switch --ask --option extra-substituters https://cache.numtide.com
```

## Manual maintenance and platform differences

Pi extension updates and user cleanup are manual; neither has a scheduler:

```sh
pi update --extensions
nh clean user --keep-since 7d --no-direnv --dry
```

Back up mutable Pi state and review extension sources first. Keep the Pi
executable Nix-managed. Review cleanup's dry preview before removing `--dry`;
cleanup can delete rollback generations/roots and garbage-collect store paths.

Linux-only packages/services are omitted rather than emulated. GCC is omitted
to avoid shadowing Apple's compiler/linker; use a project dev shell when needed.
There is no managed GPG-agent, Pi update timer or nh cleanup scheduler. Portable
profiles still provide Atuin/Tealdeer launchd agents. `xopen` uses macOS `open`;
terminal preferences, login-shell selection, credentials and permissions remain
manual.
