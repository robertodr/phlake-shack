{
  pkgs,
  lib,
  pkgsUnstable,
  ...
}: let
  nix4vscode-extensions = (import ./nix4vscode-extensions.nix) {
    pkgs = pkgs;
    lib = lib;
  };
in {
  programs.vscode = {
    enable = true;
    package = pkgsUnstable.vscode;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    mutableExtensionsDir = false;

    extensions = with lib; lists.flatten (map attrsets.attrValues (attrsets.attrValues nix4vscode-extensions));

    userSettings = {
      "editor.formatOnSave" = true;
      "editor.rulers" = [
        80
        120
      ];
      "editor.stickyScroll.enabled" = true;
      "editor.minimap.enabled" = true;
      "editor.minimap.showSlider" = "always";
      "editor.minimap.maxColumn" = 100;
      "editor.minimap.renderCharacters" = false;
      "editor.minimap.size" = "fill";
      "editor.smoothScrolling" = true;
      "editor.guides.bracketPairs" = "active";
      "[git-commit]" = {
        "editor.rulers" = [
          50
        ];
      };
      "editor.fontFamily" = "'JuliaMono', 'Fira Code Retina', Consolas, 'Courier New', monospace";
      "extensions.autoCheckUpdates" = false;
      "files.trimFinalNewlines" = true;
      "files.trimTrailingWhitespace" = true;
      "files.insertFinalNewline" = true;
      "git.mergeEditor" = true;
      "telemetry.telemetryLevel" = "off";
      "update.mode" = "none";
      "workbench.sideBar.location" = "right";
      "workbench.tree.indent" = 11;
      "workbench.tree.renderIndentGuides" = "always";
      "workbench.colorCustomizations" = {
        "tree.indentGuidesStroke" = "#999999";
      };
      "workbench.tree.enableStickyScroll" = true;
      "debug.toolBarLocation" = "commandCenter";
      # NOTE needed to get past an immediate crash after startup :(
      "window.titleBarStyle" = "custom";
      "gitlens.plusFeatures.enabled" = false;
    };
  };

  home.file.".vscode/argv.json".text = builtins.toJSON {
    enable-crash-reporter = false;
    password-store = "gnome-libsecret";
  };
}
