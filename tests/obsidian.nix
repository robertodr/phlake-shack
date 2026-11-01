{ pkgs, kellanved }:
let
  files = kellanved.config.home-manager.users.roberto.home.file;
  vault = "Workspace/robertodr/research-wiki/.obsidian";
  plugin = "${vault}/plugins/typst-mate";
in
assert pkgs.lib.assertMsg (
  builtins.hasAttr "${vault}/app.json" files
  && builtins.hasAttr "${vault}/community-plugins.json" files
  && builtins.hasAttr plugin files
  && builtins.hasAttr "${plugin}/data.json" files
) "Research wiki must receive Obsidian settings and Typst Mate";
pkgs.runCommand "obsidian-vault-check"
  {
    nativeBuildInputs = [ pkgs.jq ];
  }
  ''
    jq -e '.pdfExportSettings.pageSize == "A4"' ${files."${vault}/app.json".source}
    jq -e 'index("typst-mate") != null' ${files."${vault}/community-plugins.json".source}
    jq -e '.id == "typst-mate"' ${files.${plugin}.source}/manifest.json
    jq -e '.patchPDFExport == true and .baseColor == "#000000" and .autoBaseColor == true' \
      ${files."${plugin}/data.json".source}
    test -s ${files.${plugin}.source}/main.js
    test -s ${files.${plugin}.source}/styles.css
    touch "$out"
  ''
