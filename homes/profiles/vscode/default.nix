{
  pkgs,
  ...
}:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    mutableExtensionsDir = false;

    profiles.default = {
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      extensions = pkgs.nix4vscode.forVscode [
        "Gruntfuggly.todo-tree"
        "aaron-bond.better-comments"
        "adpyke.codesnap"
        "asvetliakov.vscode-neovim"
        "github.copilot"
        "github.copilot-chat"
        "github.vscode-github-actions"
        "github.vscode-pull-request-github"
        "ms-azuretools.vscode-docker"
        "ms-vscode-remote.remote-containers"
        "ms-vscode-remote.remote-ssh"
        "ms-vscode.cpptools-extension-pack"
        "ms-vsliveshare.vsliveshare"
        "nefrob.vscode-just-syntax"
        "oderwat.indent-rainbow"
        "openai.chatgpt"
      ];

      userSettings = {
        "editor.formatOnSave" = true;
        "editor.rulers" = [
          80
          120
        ];
        "editor.lineNumbers" = "relative";
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
        "extensions.experimental.affinity" = {
          "asvetliakov.vscode-neovim" = 1;
        };
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
        "dev.containers.defaultExtensions" = [
          "Gruntfuggly.todo-tree"
          "aaron-bond.better-comments"
          "github.copilot"
          "github.copilot-chat"
          "github.vscode-github-actions"
          "github.vscode-vscode-pull-request-github"
          "nefrob.vscode-just-syntax"
          "oderwat.indent-rainbow"
          "openai.chatgpt"
        ];
        "cmake.pinnedCommands" = [
          "workbench.action.tasks.configureTaskRunner"
          "workbench.action.tasks.runTask"
        ];
        "cmake.options.statusBarVisibility" = "hidden";
        "cmake.options.advanced" = {
          "build" = {
            "statusBarVisibility" = "inherit";
          };
          "ctest" = {
            "statusBarVisibility" = "icon";
          };
          "launch" = {
            "statusBarVisibility" = "inherit";
          };
          "debug" = {
            "statusBarVisibility" = "inherit";
          };
        };
      };
    };
  };

  home.file.".vscode/argv.json".text = builtins.toJSON {
    enable-crash-reporter = false;
    password-store = "gnome-libsecret";
  };
}
