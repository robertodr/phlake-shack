{
  runCommand,
  desktop-file-utils,
  jq,
  package,
}:

runCommand "oleafly-install-check"
  {
    nativeBuildInputs = [
      desktop-file-utils
      jq
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

    test -e ${package.tests.toolchain}
    test -e ${package.tests.templates}

    ${package}/bin/oleafly --version | grep -F '${package.version}'
    test -x ${package}/bin/oleafly-desktop
    test -x ${package}/bin/oleafly-cli
    for notice in d2/LICENSE harper.js/LICENSE pdfjs-dist/LICENSE \
      pdfjs-dist/wasm/LICENSE_JBIG2 pdfjs-dist/wasm/LICENSE_OPENJPEG \
      pdfjs-dist/wasm/LICENSE_QCMS SOURCES.md; do
      test -s "${package}/share/doc/oleafly/third-party/$notice"
    done
    find ${package}/share/applications -name '*.desktop' -print0 \
      | xargs -0 -r desktop-file-validate

    ${package}/libexec/oleafly/tectonic --version
    ${package}/libexec/oleafly/typst --version
    ${package}/bin/tectonic-biber --version
    printf '# Test\n' | ${package}/libexec/oleafly/pandoc -f markdown -t html | grep -F '<h1'

    # Exercise the packaged Typst executable offline without requiring fonts.
    printf '#rect(width: 10pt, height: 10pt)\n' > smoke.typ
    ${package}/libexec/oleafly/typst compile smoke.typ smoke.pdf
    test -s smoke.pdf

    # Instantiate a real bundled (read-only store) template, then overwrite its
    # main document as the GUI's research-project creation does.
    ${package}/bin/oleafly new "$PWD/project" --template blank-typst \
      --name "Template smoke" --no-git --json --no-input > new-project.json
    jq -e '.ok == true' new-project.json
    test -w project/main.typ
    printf '#rect(width: 10pt, height: 10pt)\n' > project/main.typ

    # Test the application's own engine discovery and build pipeline too.
    ${package}/bin/oleafly build -C "$PWD/project" --main main.typ \
      --offline --json --no-input -o "$PWD/cli-smoke.pdf"
    test -s cli-smoke.pdf

    # The embedded default, installed catalog and actual compiler must agree.
    version=$(jq -r '.typst.bundled' ${package}/share/oleafly/typst-toolchain.json)
    ${package}/bin/oleafly config get --global typst.default_version --json \
      | jq -e --arg version "$version" '.ok == true and .value == $version'
    ${package}/libexec/oleafly/typst --version | grep -F "typst $version "
    ${package}/bin/oleafly typst versions --json \
      | jq -e --arg version "$version" '
        .ok == true and .typst.bundledVersion == $version and
        (.typst.versions | all(.downloadBytes == null))'
    if ${package}/bin/oleafly typst install 999.0.0 --json --no-input > download.json; then
      echo "The distribution build offered a vendor toolchain download" >&2
      exit 1
    fi
    jq -e '.ok == false and .error.code == "typst_toolchain.not_offered"' download.json

    jq -n --arg version "$version" '{name: "smoke", engine: "typst",
      main_doc: "main.typ", typst: {version: $version}}' > project/project.json
    ${package}/bin/oleafly build -C "$PWD/project" --offline --json --no-input \
      -o "$PWD/pinned-smoke.pdf"
    test -s pinned-smoke.pdf

    jq '.typst.version = "999.0.0"' project/project.json > project/pin.json
    mv project/pin.json project/project.json
    if ${package}/bin/oleafly build -C "$PWD/project" --offline --json --no-input \
      > wrong-pin.json; then
      echo "An unavailable Typst pin silently used the packaged compiler" >&2
      exit 1
    fi
    jq -e '.ok == false and .error.kind == "missing_tool" and
      (.error.message | contains("999.0.0"))' wrong-pin.json
    touch "$out"
  ''
