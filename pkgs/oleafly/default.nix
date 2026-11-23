{
  lib,
  stdenv,
  stdenvNoCC,
  rustPlatform,
  applyPatches,
  runCommand,
  fetchFromGitHub,
  fetchurl,
  fetchpatch,
  fetchPnpmDeps,
  pnpm_11,
  pnpmConfigHook,
  nodejs_24,
  cargo-tauri,
  callPackage,
  pkg-config,
  jq,
  wrapGAppsHook3,
  glib-networking,
  dbus,
  webkitgtk_4_1,
  openssl,
  sqlite,
  git,
  xdg-utils,
  tectonic,
  biber-for-tectonic,
  pandoc,
  typst,
  tinymist,
  texlab,
}:

assert lib.assertMsg (lib.all (version: builtins.match "[0-9]+[.][0-9]+[.][0-9]+" version != null) [
  typst.version
  tinymist.version
  texlab.version
]) "Oleafly's externally managed tools require numeric major.minor.patch versions";

assert lib.assertMsg (
  lib.versions.majorMinor typst.version == lib.versions.majorMinor tinymist.version
) "Oleafly's packaged Typst and Tinymist must support the same minor line";

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "oleafly";
  version = "0.4.13";

  src = fetchFromGitHub {
    owner = "Oleafly";
    repo = "Oleafly";
    tag = "v${finalAttrs.version}";
    hash = "sha256-cI10egK+vCa/EikHnZfoyBp4NQILl9qV3x1gm+im8H4=";
  };

  patches = [
    # Upstream #519 landed after v0.4.13. Drop this backport at the next release.
    (fetchpatch {
      name = "oleafly-external-language-servers-519.patch";
      url = "https://api.github.com/repos/Oleafly/Oleafly/commits/2b0070cae77ed85402ad5fccfae8e632adc5e996";
      curlOptsList = [
        "-H"
        "Accept: application/vnd.github.diff"
      ];
      excludes = [ "CHANGELOG.md" ];
      hash = "sha256-BLqoykWcMXe8HQ3Jdktrmx1YpejoggZH4uXymHKcDQQ=";
    })
    ./writable-template-copies.patch
  ];

  cargoHash = "sha256-FiCR7O2stRdJTiyvqQ/eply0M2FYhQFOt10elek6P5Q=";

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 5;
    hash = "sha256-gfZb+zp0A7oZA9m7Xb0uRpDb0del7LtJ62wDowVuG98=";
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    pkg-config
    jq
    wrapGAppsHook3
  ];

  buildInputs = [
    dbus
    openssl
    webkitgtk_4_1
    glib-networking
    sqlite
  ];

  postPatch = ''
    cp ${finalAttrs.passthru.toolchainCatalog} src-tauri/resources/typst-toolchain.json

    # The frontend is built separately so Rust packaging changes do not rebuild it.
    jq '.build.beforeBuildCommand = "" | .bundle.createUpdaterArtifacts = false' \
      src-tauri/tauri.conf.json > tauri.conf.json.tmp
    mv tauri.conf.json.tmp src-tauri/tauri.conf.json

    # The upstream launcher dispatches command-line arguments to the CLI.
    substituteInPlace src-tauri/linux/oleafly \
      --replace-fail /usr/bin/oleafly-desktop "$out/bin/oleafly-desktop" \
      --replace-fail /usr/bin/oleafly-cli "$out/bin/oleafly-cli"

    # Tauri's build script stages the compilers even when making no AppImage.
    # Use Nix-built tools, not scripts/fetch-*.sh's prebuilt downloads.
    mkdir -p src-tauri/binaries
    ln -s ${lib.getExe tectonic} src-tauri/binaries/tectonic-${stdenv.hostPlatform.rust.rustcTarget}
    ln -s ${lib.getExe pandoc} src-tauri/binaries/pandoc-${stdenv.hostPlatform.rust.rustcTarget}
    ln -s ${lib.getExe typst} src-tauri/binaries/typst-${stdenv.hostPlatform.rust.rustcTarget}
    ln -s ${lib.getExe biber-for-tectonic} src-tauri/binaries/tectonic-biber-${stdenv.hostPlatform.rust.rustcTarget}
  '';

  preBuild = ''
    cp -r ${finalAttrs.passthru.frontend} dist
  '';

  buildAndTestSubdir = "src-tauri";

  # Upstream uses a single codegen unit and fat LTO for bundle size. Thin LTO
  # permits parallel code generation for this large desktop crate.
  env = {
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
    CARGO_PROFILE_RELEASE_LTO = "thin";
  };

  passthru.patchedSource = applyPatches {
    name = "oleafly-patched-source-${finalAttrs.version}";
    inherit (finalAttrs) src patches;
  };

  passthru.languageServerEnvironment = {
    OLEAFLY_TEXLAB = lib.getExe texlab;
    OLEAFLY_TINYMIST = lib.getExe tinymist;
  };

  passthru.toolchainCatalog =
    runCommand "oleafly-toolchain-catalog.json" { nativeBuildInputs = [ jq ]; }
      ''
        jq -e --arg typstVersion ${lib.escapeShellArg typst.version} \
          --arg tinymistVersion ${lib.escapeShellArg tinymist.version} \
          --arg typstMinor ${lib.escapeShellArg (lib.versions.majorMinor typst.version)} \
          -f ${./toolchain-catalog.jq} \
          ${finalAttrs.src}/src-tauri/resources/typst-toolchain.json > "$out"
      '';

  passthru.tests.toolchain = callPackage ./toolchain-tests.nix {
    inherit (finalAttrs.passthru) patchedSource toolchainCatalog languageServerEnvironment;
    inherit typst tinymist texlab;
  };

  passthru.tests.templates = callPackage ./template-tests.nix {
    inherit (finalAttrs.passthru) patchedSource;
  };

  passthru.frontend = stdenvNoCC.mkDerivation {
    pname = "oleafly-frontend";
    inherit (finalAttrs) version pnpmDeps;
    # Keep Rust-only fixes out of the frontend's cache key.
    src = applyPatches {
      name = "oleafly-patched-source-${finalAttrs.version}";
      inherit (finalAttrs) src;
      patches = [ (builtins.head finalAttrs.patches) ];
    };
    env = {
      NODE_OPTIONS = "--max-old-space-size=8192";
    };
    nativeBuildInputs = [
      nodejs_24
      pnpm_11
      pnpmConfigHook
    ];
    buildPhase = ''
      runHook preBuild
      pnpm build
      runHook postBuild
    '';
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      pnpm exec vitest run --maxWorkers=2 \
        src/lib/language-service/runtime-profile.test.ts \
        src/lib/language-service/json-rpc.test.ts \
        src/lib/analysis/tinymist-matching.test.ts \
        src/lib/analysis/language-service-controller.test.ts \
        src/lib/language-service/tauri-transport.validation.test.ts \
        src/lib/skills.test.ts
      # Agent Skills names must match their immutable resource directories.
      node --input-type=module <<'JS'
      import assert from 'node:assert/strict';
      import { readdirSync, readFileSync } from 'node:fs';
      const root = 'src-tauri/resources/skills';
      const skills = readdirSync(root, { withFileTypes: true }).filter(e => e.isDirectory());
      assert(skills.length > 0);
      for (const { name } of skills) {
        const content = readFileSync(root + '/' + name + '/SKILL.md', 'utf8');
        const declared = content.match(/^name: (.+)$/m)?.[1];
        assert.equal(declared, name);
        assert(name.length <= 64 && /^[a-z0-9]+(-[a-z0-9]+)*$/.test(name), name);
      }
      console.log('Validated ' + skills.length + ' bundled Agent Skills names');
      JS
      (cd node_modules && sha256sum --check ${./wasm.sha256})
      runHook postCheck
    '';
    installPhase = ''
      runHook preInstall
      cp -r dist "$out"

      # Preserve notices for the npm-distributed WebAssembly components.
      for component in harper.js pdfjs-dist; do
        install -Dm644 "node_modules/$component/LICENSE" "$out/third-party/$component/LICENSE"
      done
      for folder in wasm cmaps iccs standard_fonts; do
        mkdir -p "$out/third-party/pdfjs-dist/$folder"
        install -m644 node_modules/pdfjs-dist/$folder/LICENSE* \
          "$out/third-party/pdfjs-dist/$folder/"
      done
      runHook postInstall
    '';
  };

  passthru.tests.install = callPackage ./tests.nix {
    package = finalAttrs.finalPackage;
  };

  # Run upstream's fake-server tests and a real Nix-store-path resolver check.
  # The rest of the desktop suite includes GUI/network integration tests.
  doCheck = true;
  nativeCheckInputs = [ nodejs_24 ];
  preCheck = ''
    cp ${./external-server-tests.rs} src-tauri/src/language_service/external/nix_tests.rs
    printf '\n#[cfg(test)]\nmod nix_tests;\n' >> src-tauri/src/language_service/external.rs
    export NIX_CHECK_TEXLAB_VERSION=${lib.escapeShellArg texlab.version}
    export NIX_CHECK_TINYMIST_VERSION=${lib.escapeShellArg tinymist.version}
    export NIX_CHECK_TYPST_VERSION=${lib.escapeShellArg typst.version}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        key: value: "export ${key}=${lib.escapeShellArg value}"
      ) finalAttrs.passthru.languageServerEnvironment
    )}
  '';
  cargoTestFlags = [
    "--lib"
    "language_service::external::"
  ];

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${
        lib.makeBinPath [
          git
          xdg-utils
        ]
      }
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          key: value: "--set ${key} ${lib.escapeShellArg value}"
        ) finalAttrs.passthru.languageServerEnvironment
      )}
    )
  '';

  postInstall = ''
    install -Dm644 LICENSE "$out/share/doc/oleafly/LICENSE"
    install -Dm644 src-tauri/resources/typst-toolchain.json "$out/share/oleafly/typst-toolchain.json"
    cp -r --no-preserve=mode ${finalAttrs.passthru.frontend}/third-party "$out/share/doc/oleafly/"
    install -Dm644 ${./wasm-sources.md} "$out/share/doc/oleafly/third-party/SOURCES.md"
    install -Dm644 ${
      fetchurl {
        # @terrastruct/d2's npm tarball omits its license file.
        url = "https://raw.githubusercontent.com/terrastruct/d2/581c91096b62d644fb5168313142c836b7e68e74/LICENSE.txt";
        hash = "sha256-Uk00vJ5o80A+yP7iY1SHSJVv0Slz0Lv+yWcSQZJxWwk=";
      }
    } "$out/share/doc/oleafly/third-party/d2/LICENSE"
    substituteInPlace \
      "$out"/share/applications/*.desktop \
      "$out"/share/kio/servicemenus/*.desktop \
      "$out"/share/nemo/actions/*.nemo_action \
      --replace-fail /usr/bin/oleafly-desktop "$out/bin/oleafly-desktop"

    # Do not retain copies of the tools staged by build.rs / the deb bundler.
    for tool in tectonic pandoc typst; do
      rm "$out/libexec/oleafly/$tool"
    done
    ln -s ${lib.getExe tectonic} "$out/libexec/oleafly/tectonic"
    ln -s ${lib.getExe pandoc} "$out/libexec/oleafly/pandoc"
    ln -s ${lib.getExe typst} "$out/libexec/oleafly/typst"
    rm "$out/bin/tectonic-biber"
    ln -s ${lib.getExe biber-for-tectonic} "$out/bin/tectonic-biber"
  '';

  meta = {
    description = "Desktop workspace for writing research papers in LaTeX, Typst, and Markdown";
    homepage = "https://oleafly.com";
    changelog = "https://github.com/Oleafly/Oleafly/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Plus;
    # Rust/TypeScript are built here; npm supplies the documented WASM assets.
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode
    ];
    maintainers = [ lib.maintainers.robertodr ];
    # ARM64 evaluates, but has not yet been built or runtime-tested.
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "oleafly";
  };
})
