{
  pkgs,
  nix-vscode-extensions,
  ...
}: let
vscode-extensions = (nix-vscode-extensions.extensions.${pkgs.system}.forVSCodeVersion "${pkgs.vscode.version}").vscode-marketplace;
in {
  programs.vscode = {
    enable = true;

    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    mutableExtensionsDir = false;

    userSettings = {
      "autoDocstring.docstringFormat" = "google-notypes";
      "editor.formatOnSave" = true;
      "extensions.autoCheckUpdates" = false;
      "files.trimTrailingWhitespace" = true;
      "git.mergeEditor" = true;
      "python.analysis.diagnosticMode" = "openFilesOnly";
      "python.formatting.provider" = "black";
      "telemetry.telemetryLevel" = "off";
      "update.mode" = "none";
      "cmake.configureOnOpen" = true;
      "workbench.sideBar.location" = "right";
    };

    extensions =
      with vscode-extensions; [
        charliermarsh.ruff
        graphite.gti-vscode
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
