# External language-server support

Oleafly v0.4.13 includes the Agent Skills naming fixes from
[Oleafly #488](https://github.com/Oleafly/Oleafly/issues/488).
External language-server support merged **after** that release in
[Oleafly #519](https://github.com/Oleafly/Oleafly/pull/519), resolving
[#470](https://github.com/Oleafly/Oleafly/issues/470).

The derivation backports upstream commit
`2b0070cae77ed85402ad5fccfae8e632adc5e996` with a hash-pinned `fetchpatch`.
Only the changelog hunks are excluded because they target unreleased main,
not the release's changelog. The implementation and upstream tests are unchanged.
Drop the backport when updating to a release containing that commit.
The former downstream external-server implementation is no longer applied.

## Upstream interface

Unconfigured upstream builds keep their existing archive verification and
installer behavior. Operators/distributions can instead provide:

| Variable | Meaning |
| --- | --- |
| `OLEAFLY_TEXLAB` | Absolute path to an externally managed TexLab executable |
| `OLEAFLY_TINYMIST` | Absolute path to an externally managed Tinymist executable |

There are **no declared-version environment variables or Vite version overrides**.
Upstream probes TexLab with `--version`, Tinymist with `-V`, and its embedded
Typst version with `--version`. The install-status IPC response marks external
servers with `external: true`; the frontend accepts their reported versions.
This also handles nixpkgs' reproducible Tinymist build, whose short `-V` output
reports the server version even when its verbose first line omits that version.

Invalid paths, unrecognized or failed version probes, and a Tinymist built for
a different Typst minor line fail closed rather than triggering vendor downloads.
Upstream reuses its program-locator checks, rejects replaceable executables,
bounds probe output and execution time, and caches results.
Configured servers launch in place with upstream's runtime profiles and process
containment, without copying their binaries to app data or checking them against
hashes for different vendor release artifacts.

This is trusted operator configuration, not a sandbox for arbitrary executables.

## Nix-specific policy

The wrappers set only the two executable paths, using fixed Nix-store paths
rather than ambient overrides. Change package dependencies to change tools.

`toolchain-catalog.jq` remains a separate distribution policy. It keeps the
packaged Typst release's real capabilities and corresponding Tinymist minor-line
profile, records packaged versions, and removes vendor download artifacts.
Arbitrary vendor Typst installations are not offered on NixOS. Existing
incompatible pins fail; users must choose a compatible project toolchain or a
different package build. Unknown release dates stay blank.

Evaluation rejects nonnumeric package versions and mismatched Typst/Tinymist
minor lines. Catalog generation rejects compiler versions without known
capabilities. Runtime probes additionally verify the actual executables.

## Tests and review scope

- The package check phase runs upstream's real external-server tests, including
  fake-server version probes, failure/timeout handling, path restrictions,
  caching and Typst compatibility. A downstream regression probes the actual
  Nix-store executables, then runs builder-owned copies through the real resolver,
  checking reported versions and accepting/rejecting Typst minor lines.
  Nix user namespaces can map store-file owners to nobody; copies avoid this
  test-only ownership mismatch without weakening upstream's security checks.
  On this host, the deployed store binaries and their directories are root-owned.
- The focused toolchain check verifies packaged version output and catalog policy.
  Real Nix-built servers perform LSP initialization, document-symbol requests,
  shutdown and exit offline.
- Frontend checks cover upstream external-server IPC/controller handling,
  transport validation, profiles, JSON-RPC, Tinymist matching and skills.
  All 210 selected frontend tests pass. Each of the 39 bundled skills' frontmatter
  names matches its directory and the Agent Skills lowercase naming rules.
  All five recorded WASM byte hashes still match.
- Install tests check metadata and real offline builds with no pin, a matching
  pin, and an unavailable pin that must fail.

These checks are not GUI/editor acceptance, native ARM64 validation, or a run of
the complete desktop Rust test suite.

## Writable template copies (separate downstream fix)

`writable-template-copies.patch` still applies to v0.4.13. Rust's `fs::copy`
preserves permissions: a bundled `0444` template otherwise becomes a read-only
project file, so project creation fails when preview contents overwrite it.
Copied files gain owner-write permission on Unix, preserving other mode bits;
non-Unix platforms clear the read-only attribute. Sources stay unchanged.

`tests.templates` compiles the actual patched copy routine and constants, testing
preview overwrite and editable nested files with executable bits preserved and
no additional group/world write access. These are not GUI acceptance tests.

The independently prepared upstream fix with native core tests is preserved at
[oleafly-template-fix.patch](../../docs/development/oleafly-template-fix.patch).
Its historical baseline is `65782b79c9df73a98ccb87f0e2b30ac05a5de24f`;
the two regressions failed before the fix and the core suite passed afterward
(756 tests). That historical result is not a v0.4.13 full-suite result.

Oleafly's [CLA](https://github.com/Oleafly/Oleafly/blob/main/.github/CONTRIBUTING_CLA.md)
requires human review and acceptance; the agent has not provided acceptance.
No template-fix PR has been opened. External-server support is now upstream and
does not need a separate implementation PR from us.
