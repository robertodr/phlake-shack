# Package selections and binary caches

## llm-agents packages come from upstream CI

`pkgs.llm-agents` is provided by a small overlay in `flake.nix`
(`llmAgentsOverlay`) that exposes `llm-agents.packages.${system}` unchanged.
Every agent tool (GitButler and `but`, Claude Code, ccstatusline, Copilot CLI,
Codegraph, CodeRabbit CLI, Qmd, RTK, skills, Herdr, Pi) is therefore the exact
derivation built by upstream CI against llm-agents' own locked nixpkgs, and is
substituted from Numtide's cache instead of being compiled locally.

This replaces `llm-agents.overlays.shared-nixpkgs`, which rebuilt the packages
against the host package set: their derivation identities differed from
upstream CI, so nothing was ever cached and the Rust/Bun tools compiled on every
host. It also needed the `installAgentSkills` hook injected from llm-agents'
nixpkgs; packages built by llm-agents' own package set already have it. The
cost is a second nixpkgs closure for these tools' runtime dependencies, which is
downloaded rather than built. The upstream package set uses its own locked
nixpkgs dependency; do not make it follow the host's stable or unstable input,
as that would again change every store path.

The NixOS hosts' shared Nix profile includes Numtide's cache and published
verification key, with NAR signature checking still enabled. Crokus enables it
through Home Manager's `nix.settings`; see its runbook for the one-time daemon
trust step. See the
[upstream cache documentation](https://github.com/numtide/llm-agents.nix#binary-cache).
Cache hits depend on upstream CI having built the locked revision; check with
`nix path-info --store https://cache.numtide.com <out-path>` before a switch.

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
