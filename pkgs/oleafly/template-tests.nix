{
  runCommand,
  stdenv,
  rustc,
  python3,
  patchedSource,
}:

runCommand "oleafly-template-copy-check"
  {
    nativeBuildInputs = [
      stdenv.cc
      rustc
      python3
    ];
  }
  ''
    # Compile the real copy routine and its constants, without requiring the GUI
    # or substituting a reimplementation. Missing boundaries fail on updates.
    python - <<'PY'
    import pathlib
    import re

    source = pathlib.Path("${patchedSource}/crates/oleafly-core/src/templates.rs").read_text()
    constants = [
        re.search(r"pub const META_FILES:.*?;", source, re.S).group(),
        re.search(r"pub const MAX_COPY_DEPTH:.*?;", source).group(),
    ]
    routine = source[source.index("pub fn copy_tree_with("):source.index("\npub fn missing_font_packs(")]
    pathlib.Path("copy-tree.rs").write_text("\n".join(constants + [routine]))
    PY
    cp ${./template-copy-tests.rs} tests.rs
    rustc --edition 2021 --test tests.rs -o template-copy-tests
    ./template-copy-tests
    touch "$out"
  ''
