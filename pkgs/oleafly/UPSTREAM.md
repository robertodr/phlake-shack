# External language-server support

`external-language-servers.patch` is a local, upstream-oriented patch against
Oleafly v0.4.12. Its interface is proposed in
[Oleafly #470](https://github.com/Oleafly/Oleafly/issues/470); no implementation PR
has been submitted.

## Interface

Unconfigured upstream builds keep their existing archive verification and
installer behavior. Operators/distributions can instead provide:

| Variable | Meaning |
| --- | --- |
| `OLEAFLY_TEXLAB` | Absolute path to an externally managed TexLab executable |
| `OLEAFLY_TEXLAB_VERSION` | Its numeric `major.minor.patch` version |
| `OLEAFLY_TINYMIST` | Absolute path to an externally managed Tinymist executable |
| `OLEAFLY_TINYMIST_VERSION` | Its numeric `major.minor.patch` version |
| `OLEAFLY_TINYMIST_TYPST_MINOR` | Compatible Typst `major.minor`, e.g. `0.14` |

A server's configuration is optional as a whole, but partial/invalid settings are
errors: they must not trigger fallback downloads. Paths must be absolute regular
files and, on Unix, executable. Symlinks to such files are supported. Configuration
is trusted operator input; it is not read from project metadata or searched on
PATH. This is not a sandbox for arbitrary executable files.

Configured servers report `installed` / `already_installed`, and are launched
in place with the existing server arguments, process containment and LSP profiles.
Their files are neither copied to app data nor checked against hashes belonging
to *different upstream release binaries*. Vendor integrity checks are unchanged
for the unconfigured path. A configured Tinymist rejects projects/defaults on
another Typst minor line, rather than downloading a replacement or silently
using an incompatible server.

The frontend currently checks exact server versions. Distribution frontend builds
must therefore set `VITE_OLEAFLY_TEXLAB_VERSION` and
`VITE_OLEAFLY_TINYMIST_VERSION` to match their backend configuration. This is a
build-time contract, not arbitrary runtime version negotiation. An upstream
review may prefer exposing managed-server metadata through IPC instead; that
would require corresponding frontend/protocol changes.

## Nix-specific policy

The derivation supplies the above variables using fixed Nix-store paths and
package versions. These wrapper settings are deliberately not overridden by
ambient shell variables. Change the package's dependencies to change its tools.

`toolchain-catalog.jq` is a separate distribution policy, not a change to upstream's
default downloader. It keeps the packaged Typst release's real capabilities and
the corresponding Tinymist minor-line profile, records the packaged versions,
and removes all vendor download artifacts. Thus this package does not offer
arbitrary vendor Typst installations on NixOS. Existing incompatible pins fail;
users must choose a compatible project toolchain or a different package build.

When a Tinymist minor-line profile is reused for another patch release, its
unknown release date is left blank rather than copied from a different release.

The build fails for nonnumeric tool versions, if Typst/Tinymist minor lines differ,
or if upstream's catalog has no capability/profile entry for the packaged tools.
Updating dependencies must not silently reuse another compiler version's capabilities.

## Tests and review scope

- Rust tests exercise the actual patched external-server module through a small
  std-only harness: absent/partial settings, versions, paths, executability and
  Typst compatibility. This avoids compiling unrelated GUI integration tests.
- Real Nix-built servers perform LSP initialization, document-symbol requests,
  shutdown and exit offline. This tests the server processes independently of
  Tauri's IPC/session machinery, not the complete editor integration.
- Selected frontend tests cover profiles, version overrides, JSON-RPC and Tinymist
  matching, including the unchanged default upstream profile.
- Package install tests check default-version metadata and real offline builds
  with no pin, a matching pin, and an unavailable pin that must fail.

## Writable template copies (separate upstream fix)

`writable-template-copies.patch` fixes project creation from read-only installed
resources. Rust's `fs::copy` preserves file permissions: a bundled `0444` template
becomes a read-only project file, so research-project creation fails when it
writes the preview contents over `main.typ` (and other engines can be affected).
Copied files now gain owner-write permission on Unix, preserving all other mode
bits; non-Unix platforms clear the read-only attribute. The source stays unchanged.

`tests.templates` compiles the actual patched copy routine and constants. Its two
regressions failed before the fix (including OS error 13) and pass afterward:
preview overwrite and editable nested files with executable bits preserved and
no additional group/world write access. These are not GUI acceptance tests.

The separately prepared upstream patch, including native core unit tests, is
preserved at [oleafly-template-fix.patch](../../docs/development/oleafly-template-fix.patch).
It targets upstream main at `65782b79c9df73a98ccb87f0e2b30ac05a5de24f` and is not an
additional patch applied by this derivation. Its two regressions fail before the
fix; the full core crate suite passes afterward (756 tests). Local validation used
Rust 1.95.0, not upstream's pinned 1.98.1. Strict Clippy encounters an unrelated
existing `nonminimal_bool` warning in `context/markdown.rs:421`; allowing only
that lint makes the core all-targets check pass. The full workspace was not run.

Submit this independently from external language-server support. Oleafly's
[CLA](https://github.com/Oleafly/Oleafly/blob/main/.github/CONTRIBUTING_CLA.md)
requires human review and acceptance before merging; no acceptance has been
provided by the agent. No upstream template-fix PR has been opened.

Before upstreaming the language-server patch, review the environment-variable/
build-time contract with Oleafly maintainers and add end-to-end editor/IPC coverage. Do not represent the
headless server tests as GUI acceptance or as the full upstream Rust test suite.
