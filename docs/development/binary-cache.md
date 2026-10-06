# Avoiding custom GitButler and Inkscape builds

## GitButler GUI and CLI

Keep `llm-agents`' nixpkgs input pinned to the revision in its own upstream
`flake.lock`. The shared overlay builds against the host package set, so its
GitButler derivation does not match upstream CI even at the same application
version. Following our separate unstable input also changes upstream package
identities.

The desktop GitButler and shared `but` CLI now come directly from
`llm-agents.packages.x86_64-linux`. Other shared-overlay selections remain in
place. There is no nested nixpkgs override in the input declaration: upstream's
own lock supplies its CI dependency, recorded in our `flake.lock`. Local host
invariants check both the revision and inherited input declaration against
upstream. During migration from the old `follows`, only the nested input's
`original` metadata needed correction; its locked revision stayed unchanged.
Existing host input revisions were not upgraded for this fix.

Numtide's cache and published signature-verification key are configured in the
shared Nix profile. NAR signature checking remains enabled. Reference:
<https://github.com/numtide/llm-agents.nix#binary-cache>.

## Inkscape and Stylix

Inkscape uses ordinary `pkgs.inkscape`, with no special package argument or
application patch. Stylix has no Inkscape-specific target; its global GtkSourceView
overlay previously changed the dependency hash and caused a custom source build.

The NixOS GtkSourceView target is now disabled, preventing package overrides.
The Home Manager GtkSourceView target is enabled instead: Stylix generates
user-level syntax XML for GtkSourceView 2, 3, 4 and 5 without changing application
packages. The GTK theme and syntax palette are retained. Theme changes regenerate
small XML files rather than rebuilding GtkSourceView or Inkscape.

## First build and verification

The NixOS cache settings take effect only after human-operated activation. Before
that, an unprivileged build can supply the cache/key temporarily:

```sh
nix build .#nixosConfigurations.kellanved.config.system.build.toplevel --no-link \
  --option extra-substituters https://cache.numtide.com \
  --option extra-trusted-public-keys \
  'niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g='
```

The selected GitButler 0.22.3, `but` 0.22.3 and Inkscape 1.4.4 artifacts were
successfully realized with local builds disabled (`--max-jobs 0`, no remote
builders), using the official/Numtide caches and signature checking. This proves
substitution for these pinned artifacts, not that all future versions will be
cached. Native Nix cache queries succeeded even when direct HTTP narinfo probes
returned 403; a direct 403 alone is not proof that an artifact is absent.

No system activation is performed by the automated checks. The local
`host-invariants` check still needs the private Framework baseline, intentionally
excluded from public source and installation bundles.
