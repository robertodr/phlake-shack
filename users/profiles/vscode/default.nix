{ pkgs, ... }: {
  programs.vscode = {
    enable = true;

    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    userSettings = {
      "telemetry.telemetryLevel" = "off";
      "quarto.mathjax.theme" = "dark";
    };

    extensions = with pkgs.vscode-extensions;
      [
        bbenoist.nix
        ms-python.python
        ms-vscode.cpptools
        ms-vsliveshare.vsliveshare
        vscodevim.vim
        # is this needed when the python extension is installed?
        ms-toolsai.jupyter
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
          version = "1.54.0";
          sha256 = "sha256-9sszs1DTzAeblIUE48jDTeU6GDDyLFzW2eQWaw0Y5zE=";
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
          version = "0.6.34";
          sha256 = "sha256-EbjXBffpiI1z6GDzumx5Vw7JgDsXCalsf+4mOm/SzDM=";
        }

        {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.92.0";
          sha256 = "sha256-Mrfv7rhNT6H+cZcgRGPZEFFnxHp6WX9rNVs1xV6NSLw=";
        }

        {
          name = "remote-containers";
          publisher = "ms-vscode-remote";
          version = "0.260.0";
          sha256 = "sha256-MnY0NdfLEP4cDBUwuQPLFZUUxWJDH2838tq0Cslm+L4=";
        }

        {
          name = "direnv";
          publisher = "mkhl";
          version = "0.7.0";
          sha256 = "sha256-MLBPhDBU8vPVvbde3fdwhxKvQa8orUMKAAXoOfNrbh4=";
        }
      ];
  };
}
