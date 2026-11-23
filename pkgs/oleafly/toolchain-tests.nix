{
  lib,
  runCommand,
  python3,
  jq,
  patchedSource,
  toolchainCatalog,
  languageServerEnvironment,
  typst,
  tinymist,
  texlab,
}:

runCommand "oleafly-external-toolchain-check"
  {
    nativeBuildInputs = [
      python3
      jq
    ];
    env = languageServerEnvironment;
  }
  ''
    export HOME="$TMPDIR/home"
    export XDG_CACHE_HOME="$HOME/cache"
    export XDG_CONFIG_HOME="$HOME/config"
    mkdir -p "$HOME"

    # The real Rust resolver and upstream fake-server tests run in the package's
    # check phase, with their actual process-containment and path-validation code.
    "$OLEAFLY_TEXLAB" --version | grep -Fx "texlab ${texlab.version}"
    "$OLEAFLY_TINYMIST" -V | grep -Fx "tinymist ${tinymist.version}"
    "$OLEAFLY_TINYMIST" --version | grep -E '^Typst Version:[[:space:]]+${lib.escapeRegex typst.version}$'

    jq -e --arg typstMinor ${lib.escapeShellArg (lib.versions.majorMinor typst.version)} \
      --arg tinymistVersion ${tinymist.version} '
      (.typst.versions | length) == 1 and
      (.tinymist.versions | length) == 1 and
      .typst.versions[0].version == .typst.bundled and
      .tinymist.bundled == $tinymistVersion and
      .tinymist.versions[0].typstMinor == $typstMinor and
      ([.typst.versions[], .tinymist.versions[]] | all(.targets == {}))
    ' ${toolchainCatalog}

    # A compiler update with no known capabilities must fail, not silently use
    # another release's catalog entry.
    if jq -e --arg typstVersion 999.0.0 --arg typstMinor 999.0 \
      --arg tinymistVersion 999.0.0 -f ${./toolchain-catalog.jq} \
      ${patchedSource}/src-tauri/resources/typst-toolchain.json > bad-catalog.json; then
      echo "An unknown compiler version was accepted" >&2
      exit 1
    fi

    python ${./lsp-smoke.py}
    touch "$out"
  ''
