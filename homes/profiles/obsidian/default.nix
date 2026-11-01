{ pkgs, ... }:
let
  version = "2.3.2";
  releaseUrl = "https://github.com/azyarashi/obsidian-typst-mate/releases/download/${version}";
  typstMate =
    pkgs.runCommand "obsidian-typst-mate-${version}"
      {
        main = pkgs.fetchurl {
          url = "${releaseUrl}/main.js";
          hash = "sha256-B+Qg1W1K8Hit8dS7lqh1o6bj1g7uFstC92l02N63Z3c=";
        };
        manifest = pkgs.fetchurl {
          url = "${releaseUrl}/manifest.json";
          hash = "sha256-U2Hpt0lofqUrGiDv09qApwnWtOqUGAMcy8oAcD9+Kmo=";
        };
        styles = pkgs.fetchurl {
          url = "${releaseUrl}/styles.css";
          hash = "sha256-u0LPSANUDFhiEtwlwgyROD5dkY8eCodg4Z5fmPJtCuc=";
        };
        passthru.manifestId = "typst-mate";
      }
      ''
        mkdir -p "$out"
        cp "$main" "$out/main.js"
        cp "$manifest" "$out/manifest.json"
        cp "$styles" "$out/styles.css"
      '';
in
{
  programs.obsidian = {
    enable = true;
    cli.enable = true;
    vaults."Workspace/robertodr/research-wiki" = { };
    defaultSettings = {
      app.pdfExportSettings = {
        pageSize = "A4";
        landscape = false;
        margin = "0";
        downscalePercent = 100;
      };
      communityPlugins = [
        {
          pkg = typstMate;
          settings = {
            patchPDFExport = true;
            baseColor = "#000000";
            autoBaseColor = true;
          };
        }
      ];
      corePlugins = [
        "audio-recorder"
        "backlink"
        "bases"
        "bookmarks"
        "canvas"
        "command-palette"
        "daily-notes"
        "editor-status"
        "file-explorer"
        "file-recovery"
        "footnotes"
        "global-search"
        "graph"
        "markdown-importer"
        "note-composer"
        "outgoing-link"
        "outline"
        "page-preview"
        "properties"
        "publish"
        "random-note"
        "slash-command"
        "slides"
        "switcher"
        "sync"
        "tag-pane"
        "templates"
        "webviewer"
        "word-count"
        "workspaces"
        "zk-prefixer"
      ];
    };
  };
}
