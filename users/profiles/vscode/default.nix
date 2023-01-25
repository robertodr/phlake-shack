{pkgs, ...}: {
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
          name = "gitlens";
          publisher = "eamodio";
          version = "2023.1.2404";
          sha256 = "19ld495c6hy7z6wiw9wi3jy139h6jb0fhicwzljp99kww0jdn2v1";
        }

        {
          name = "language-julia";
          publisher = "julialang";
          version = "1.40.1";
          sha256 = "1pw2s8qdgvacrb8bfxz4baszlzkc2frrvgk3n9g30vzfj0kprw84";
        }

        {
          name = "magit";
          publisher = "kahole";
          version = "0.6.36";
          sha256 = "0fkrjcw3kiggdqd81v03q80mgdv6ykckpi25mcj9jp4vz027dgg3";
        }

        {
          name = "direnv";
          publisher = "mkhl";
          version = "0.10.1";
          sha256 = "0m89sx1qqdkwa9pfmd9b11lp8z0dqpi6jn27js5q4ymscyg41bqd";
        }

        {
          name = "remote-containers";
          publisher = "ms-vscode-remote";
          version = "0.273.0";
          sha256 = "0l0d52az2cgl10ljbwqp9m05wkgch33rpsvwc8akg2ixjpavfw4v";
        }

        {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.95.2023012415";
          sha256 = "1zl0my7i70s70vxiqak8yhfqbbzk2jb97pk39iyg22flgikb2bq9";
        }

        {
          name = "cmake-tools";
          publisher = "ms-vscode";
          version = "1.14.0";
          sha256 = "0wlndmwcql7ajzb87y5lfk9ydr5d8kr28sgn1v851cz4qiq5drx1";
        }

        {
          name = "quarto";
          publisher = "quarto";
          version = "1.59.0";
          sha256 = "0piqxdf73n34pj58wf4wz4i2mkmrhg7xn96zhzaiqs1613b8cjip";
        }

        {
          name = "ruff";
          publisher = "charliermarsh";
          version = "2023.5.10190053";
          sha256 = "sha256-AjxaPDaczlQHePkb6nJCRxcisYs8lFkoBzJW5w+0Qvg=";
        }

        {
          name = "protein-viewer";
          publisher = "ArianJamasb";
          version = "0.1.0";
          sha256 = "1k5r491p4s3mymnbzjvjpkxnlvq9c4py3blbrwpf2ybjanwskjn6";
        }
      ];
  };
}
