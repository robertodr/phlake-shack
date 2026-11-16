# Bundled WebAssembly provenance

Oleafly's Rust application and TypeScript frontend are built from source. The
following third-party WebAssembly modules are distributed precompiled through
npm; they are **not** rebuilt from their original sources by this derivation.
This is reflected in `meta.sourceProvenance` (`binaryBytecode`). The npm archives
are pinned by integrity hashes in upstream's `pnpm-lock.yaml` and by the Nix
`pnpmDeps` hash. No additional runtime fetch is used for these bundled modules.

| npm package | Distributed module | Upstream source | License |
| --- | --- | --- | --- |
| `@terrastruct/d2` 0.1.33 | `d2.wasm` | [terrastruct/d2, npm gitHead](https://github.com/terrastruct/d2/tree/581c91096b62d644fb5168313142c836b7e68e74/d2js) | MPL-2.0 |
| `harper.js` 2.10.0 | `harper_wasm_bg.wasm` | [automattic/harper v2.10.0](https://github.com/automattic/harper/tree/e2773c6c8b55f028c24574819d266ca03f45c701) | Apache-2.0 |
| `pdfjs-dist` 6.3.289 | `jbig2.wasm`, `openjpeg.wasm`, `qcms_bg.wasm` | [mozilla/pdf.js v6.3.289](https://github.com/mozilla/pdf.js/tree/1c8020a7d4e43668ac287a3ecf9a8dbea17e4c56) | Apache-2.0 plus the bundled PDFium/JBIG2, OpenJPEG and qcms notices |

The archive integrity hashes were checked against the pinned lockfile, and the
five shipped module byte hashes were matched to those npm archives. This records
artifact origins, not bit-for-bit reproducibility from the linked source trees.
Harper's npm metadata does not include a `gitHead`; the source link is its matching
release tag. Updating these dependencies requires repeating the provenance and
license review, rather than reusing this inventory unchecked.

SHA-256 of the distributed modules before Vite's filename hashing:

```
7b0d5db9e148d1eba9ab7494a468a79fd92aca93fd3a89cad5876e68097170af  d2.wasm
d20b944d75acf59cd0e75ffff57663628f0aa06294b05cc0bbc719f91f9270d7  harper_wasm_bg.wasm
e6bee67724a7b5436fe8162638e3708cfc8d52b6342db69a49715e30ff27cfdc  jbig2.wasm
004a0e62db930ba9ff2a22212f4554d0bb57a0635a8287caf70f98117cee14ba  openjpeg.wasm
663d86126d5f5fcb1c61490f94353e2a8375660b8c5498ab3ebab5a34b08800e  qcms_bg.wasm
```

The Harper and PDF.js package licenses and PDF.js component/font notices are
installed alongside this file. PDF.js also retains its per-component notices in
its bundled asset directories. D2's npm tarball omits a license file, so its
MPL-2.0 text is fetched separately from the npm-reported source commit and pinned
by hash. Its covered source is available at the source link above.

PDF.js's `quickjs-eval.wasm` and Harper's slim binary are not shipped by this
frontend build. This inventory concerns the bundled WASM components; it is not
an exhaustive inventory of all Rust/JavaScript/font dependencies.
