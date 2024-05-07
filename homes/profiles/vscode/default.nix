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
    };
    extensions = with vscode-extensions; [
      #alessandrosangalli.mob-vscode-gui
      github.copilot
      github.vscode-github-actions
      mgt19937.typst-preview
      mkhl.direnv
      ms-azuretools.vscode-docker
      ms-vscode-remote.remote-containers
      #ms-vscode-remote.remote-ssh
      ms-vsliveshare.vsliveshare
      nvarner.typst-lsp
      vscodevim.vim
    ];
  };
}
# Python-related options and extensions
#"autoDocstring.docstringFormat" = "google-notypes";
#"python.analysis.diagnosticMode" = "openFilesOnly";
# FIXME see below
#"[python]" = {
#  "editor.codeActionsOnSave" = {
#    "source.fixAll" = "explicit";
#    "source.organizeImports" = "explicit";
#  };
#};
#charliermarsh.ruff
#ms-python.python
#ms-toolsai.jupyter
#njpwerner.autodocstring
# C++-related options and extensions
#"cmake.configureOnOpen" = true;
#ms-vscode.cmake-tools
#ms-vscode.cpptools
#ms-vscode.cpptools-extension-pack
#ms-vscode.cpptools-themes

