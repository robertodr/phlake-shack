# Package selections and binary caches

## Why GitButler uses explicit package arguments

`gitbutlerPackage` and `gitbutlerCli` in Home Manager's `extraSpecialArgs` select
`llm-agents.packages.${system}.gitbutler` and `.but` directly. The desktop and
development profiles consume those arguments rather than `pkgs.llm-agents`
overlay packages.

This distinction is intentional: `llm-agents.overlays.shared-nixpkgs` rebuilds
against the host package set, which changes derivation identities from upstream
CI even when application versions match. Using `pkgs.llm-agents.gitbutler` or
`pkgs.llm-agents.but` is therefore not a cache-equivalent simplification.
The upstream package set uses its own locked nixpkgs dependency; do not make it
follow the host's stable or unstable input merely to remove these arguments.
Shared-overlay application selections remain unchanged. Herdr 0.9.5 and Qmd
require the `installAgentSkills` build hook, which the stable host package set
lacks. The host overlay supplies that hook from `llm-agents`' own locked Nixpkgs
input; the applications still build against the shared host package set.

The shared Nix profile includes Numtide's cache and published verification key,
with NAR signature checking still enabled. See the
[upstream cache documentation](https://github.com/numtide/llm-agents.nix#binary-cache).
The pinned GitButler 0.22.3 and `but` 0.22.3 artifacts were previously realized
with local and remote builds disabled. That established substitution for those
artifacts, not a guarantee that every future version is cached.

## Inkscape and Stylix

Inkscape uses ordinary `pkgs.inkscape`. Stylix's NixOS GtkSourceView target is
disabled so it does not override application dependencies and cause custom
Inkscape builds. The Home Manager GtkSourceView target remains enabled to
provide syntax XML and preserve styling without rebuilding application packages.
The pinned Inkscape 1.4.4 artifact was also previously realized from caches.

These choices apply to the shared configuration. Removing Dancer's abandoned
Secure Boot/TPM experiment does not change them, update the lock file, or alter
Framework's package selection. Cache/package changes and host activation require
separate review; this document does not issue a build or activation command.
