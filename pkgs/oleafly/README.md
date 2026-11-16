# Oleafly

Oleafly v0.4.12 for Linux. `default.nix` builds the Rust/Tauri application and
TypeScript/Vite frontend from pinned sources, with Nix-managed document tools and
language servers. It does not repackage an upstream desktop binary. Five
third-party WASM modules still come precompiled through pinned npm packages;
[wasm-sources.md](wasm-sources.md) documents their origins and limitations, and
`meta.sourceProvenance` explicitly includes `binaryBytecode`.

Only the source package is exposed; there is no AppImage fallback. Nothing here
installs Oleafly into any host configuration automatically.

## Usage

```sh
nix build .#oleafly
nix run .#oleafly
nix run .#oleafly -- --version
nix build .#checks.x86_64-linux.oleafly
# Faster focused checks:
nix build .#oleafly.tests.toolchain
nix build .#oleafly.tests.templates
```

Use `path:.#…` instead while adding files that Git does not yet track. The NixOS
overlay also exposes `pkgs.oleafly`. Source outputs are exposed for x86-64 and
ARM64 Linux; ARM64 has only evaluated, not been built or runtime-tested.

## Packaging

- Source, Cargo and pnpm dependencies are hash-pinned.
- Node 24 and pnpm 11 build the frontend separately from Rust. Node needs an
  8 GiB heap plus additional memory; the backend uses thin LTO and 16 codegen
  units. Rust-only packaging changes do not invalidate the frontend cache.
- `cargo-tauri.hook` generates its own deb staging tree during the source build;
  no upstream deb/AppImage is consumed by `default.nix`.
- Tectonic, compatible Biber, Pandoc and Typst come from nixpkgs. Staged compiler
  copies are replaced with store-path links at installation.
- TexLab/Tinymist use fixed Nix executable paths and declared versions, with
  matching frontend metadata. Invalid/partial external configuration fails closed;
  unconfigured upstream builds retain vendor verification. See [UPSTREAM.md](UPSTREAM.md).
- The compiler catalog retains the packaged Typst's capabilities and compatible
  Tinymist profile, advertises no vendor compiler downloads, and rejects unknown
  capabilities or incompatible toolchain minors. Arbitrary version pins are not
  satisfied by downloading generic Linux binaries.
- GTK/WebKit/GLib networking are wrapped, SQLite is an explicit build dependency,
  and desktop/CLI dispatch paths use the Nix output rather than `/usr/bin`.
- Read-only installed templates become editable project copies without changing
  sources, losing executable bits, or adding group/world write permissions.
- WASM hashes are checked during frontend tests. Relevant npm notices are retained;
  D2's missing npm license is fetched from its reported source commit by hash.
- Updater artifact/signature generation is disabled. Update through Nix; complete
  runtime updater UI behavior remains a submission-review item.

## Validation and dependency sets

The flake's pinned nixpkgs currently provides Typst 0.14.2 and Tinymist 0.14.18.
The human operator confirmed new Typst projects, PDF preview/compilation and
completion; a LaTeX/BibLaTeX/Biber workflow; Markdown compilation; lifecycle
behavior; and rejection of an unavailable Typst pin. A globally installed Typst
can satisfy a matching compiler pin, so `999.0.0` was used for the unavailable-pin
check. These observations are not a claim of exhaustive editor/IPC testing.

The corresponding nixpkgs submission recipe was independently built and reviewed
against master snapshot `d4a0d6baf1115a52a76ea263d1a5796487ff2f1f`, with Typst 0.15.1,
Tinymist 0.15.12 and TexLab 5.26.0. `nixpkgs-review --tests` passed on x86_64-linux:
one package and all three passthru tests. That is not GUI acceptance of the newer
dependency set. The portable SQLite/provenance/notice improvements from that
validated recipe are included here; full pinned-flake rebuild results must be
kept distinct from that master-based validation.

Automated coverage:

- Seven Rust external-server configuration tests and two read-only template-copy
  regressions, compiling the actual patched routines.
- Real offline TexLab/Tinymist initialization, document symbols, shutdown and exit.
- 28 selected frontend tests plus five WASM byte-hash checks.
- Actual CLI creation of a bundled Typst template, editing and offline compilation;
  metadata agreement; matching pins; unavailable pins/vendor-install rejection.
- Desktop-file validation, tool execution, Markdown conversion and installed notices.

The full desktop Rust suite is disabled; headless server tests are not a substitute
for Tauri editor/IPC acceptance. Native ARM64 testing, explicit export/file-open
coverage and separate Wayland/X11 coverage remain outstanding.

## Project locations and isolated acceptance

Normal GUI projects live under `~/.oleafly/projects/research-…`; display names are
in each folder's `project.json`. `OLEAFLY_DATA_DIR` relocates the entire library,
including settings, not just project folders. Quit any existing app instance
before testing another build with a separate library:

```sh
OLEAFLY_DATA_DIR="$HOME/Documents/Oleafly-test" nix run .#oleafly
```

Those projects live under `~/Documents/Oleafly-test/projects/`. Do not automatically
rewrite existing project pins when changing packaged Typst/Tinymist versions.
To test rejection, close the app, back up a disposable project's manifest, change
its existing `typst.version` to `999.0.0`, reopen and check the new build/server
result rather than an old cached PDF. Restore the original version afterward.

## Updating and upstream submission

Update `version`, source/Cargo/pnpm hashes together. Review the toolchain catalog's
capabilities, keep Typst/Tinymist minors compatible, and repeat the WASM source/
license inventory when npm dependencies change. Never run upstream compiler-fetch
scripts inside the sandbox build.

- External-server design discussion: [Oleafly #470](https://github.com/Oleafly/Oleafly/issues/470).
- The separate upstream template fix and native core regressions are preserved in
  [the submission patch](../../docs/development/oleafly-template-fix.patch).
  No Oleafly implementation PR or CLA acceptance has been submitted.
- For nixpkgs, copy the source recipe as `pkgs/by-name/ol/oleafly/package.nix` with
  its referenced helper files; omit the personal flake wiring.
  Initially restrict `meta.platforms` to x86-64 unless native ARM64 is validated.
- Human review of code/descriptions, GUI confirmation against the actual master
  build, updater behavior and the bytecode/notice policy remain before publication.
  Passing automated checks do not replace nixpkgs' required human review.
