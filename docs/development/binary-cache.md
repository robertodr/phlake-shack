# Avoiding custom GitButler and Inkscape builds

## GitButler GUI and CLI

Keep `llm-agents`' nixpkgs input pinned to the revision in its own upstream
`flake.lock`. The shared overlay builds against the host package set, so its
GitButler derivation does not match upstream CI even at the same application
version. Following our separate unstable input also changes upstream package
identities.

The desktop GitButler and shared `but` CLI now come directly from
`llm-agents.packages.x86_64-linux`. Other shared-overlay selections remain in
place. The upstream CI nixpkgs pin is explicit: when updating `llm-agents`, update
that pin together with it. Local host invariants check it against the input's own
lock file. Existing host input revisions were not upgraded for this fix.

Numtide's cache and published signature-verification key are configured in the
shared Nix profile. NAR signature checking remains enabled. Reference:
<https://github.com/numtide/llm-agents.nix#binary-cache>.

## Inkscape and Stylix

Inkscape comes from the unmodified, same-pinned stable nixpkgs package set.
Stylix's global GtkSourceView override previously changed Inkscape's dependency
hash and turned it into a custom source build.

The existing Stylix syntax XML is additionally linked into the user's
`~/.local/share/gtksourceview-4/styles/stylix.xml`, where stock GtkSourceView can
find it. The existing GTK theme and global GtkSourceView configuration are not
disabled. A theme change can still rebuild the small customized GtkSourceView
package, but no longer changes Inkscape's derivation through that dependency.

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
