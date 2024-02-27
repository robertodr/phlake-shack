{
  pkgs,
  nix-vscode-extensions,
  ...
}: let
  vscode-extensions = (nix-vscode-extensions.extensions.${pkgs.system}.forVSCodeVersion "${pkgs.unstable.vscode.version}").vscode-marketplace;
in {
  programs.vscode = {
    enable = true;
    package = pkgs.unstable.vscode;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    mutableExtensionsDir = false;
    userSettings = {
      "editor.formatOnSave" = true;
      "extensions.autoCheckUpdates" = false;
      "files.trimTrailingWhitespace" = true;
      "git.mergeEditor" = true;
      "telemetry.telemetryLevel" = "off";
      "update.mode" = "none";
      "workbench.sideBar.location" = "right";
      # NOTE needed to get past an immediate crash after startup :(
      "window.titleBarStyle" = "custom";
      "autoDocstring.docstringFormat" = "google-notypes";
      "python.analysis.diagnosticMode" = "openFilesOnly";
      "cmake.configureOnOpen" = true;
      "[python]" = {
        "editor.codeActionsOnSave" = {
          "source.fixAll" = "explicit";
          "source.organizeImports" = "explicit";
        };
      };
    };
    extensions = with vscode-extensions; [
      charliermarsh.ruff
      # NOTE not really using Graphite at the moment
      #graphite.gti-vscode
      mkhl.direnv
      ms-azuretools.vscode-docker
      ms-vsliveshare.vsliveshare
      ms-python.python
      ms-toolsai.jupyter
      ms-vscode-remote.remote-containers
      # FIXME requires bleeding edge vscode?
      #ms-vscode-remote.remote-ssh
      ms-vscode.cmake-tools
      ms-vscode.cpptools
      ms-vscode.cpptools-extension-pack
      ms-vscode.cpptools-themes
      njpwerner.autodocstring
      vscodevim.vim
    ];
  };
}
