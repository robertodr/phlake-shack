{pkgs, ...}: {
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions;
      [
        bbenoist.nix
        ms-pyright.pyright
        ms-python.python
        # is this needed when the python extension is installed?
        ms-toolsai.jupyter
        ms-vscode.cpptools
        ms-vsliveshare.vsliveshare
        vscodevim.vim
      ]
      ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "language-julia";
          publisher = "julialang";
          version = "1.7.12";
          sha256 = "sha256-g6os6ktSWzUSCnLzMkGRoOhCEvU3gXcGGj2cq1NKkaE=";
        }

        {
          name = "quarto";
          publisher = "quarto";
          version = "1.43.0";
          sha256 = "sha256-4F25n0NZ+GhnzkwFvjnHFK7PX2z5Tlmp90snC2IRvkM=";
        }

        {
          name = "cmake-tools";
          publisher = "ms-vscode";
          version = "1.13.16";
          sha256 = "sha256-DMfSIsbtCaLk7xFZq4aI4Of6+2QCX/WesuBGjzOdnWw=";
        }

        {
          name = "magit";
          publisher = "kahole";
          version = "0.6.33";
          sha256 = "sha256-qrqvlOGHkLQtIu5GbG06XYbyGNMzZtui/mpk60X3djE=";
        }
      ];
  };
}
