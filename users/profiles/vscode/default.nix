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
          version = "0.269.0";
          sha256 = "0zlssgrr5d3cxivjyv6ifx6nl8ai08nf4kahsdb4w0cv0bl3hxph";
        }

        {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.95.2022122215";
          sha256 = "105bmfgi3ir0smjr7rwigwwa7ar5kklrw22qr6755dgsppbq4kpy";
        }

        {
          name = "cmake-tools";
          publisher = "ms-vscode";
          version = "1.13.32";
          sha256 = "08rimkqlcmzdw9qhm3y7lwx10mfdds11v6zflqblnxsc0ag9bcgi";
        }

        {
          name = "quarto";
          publisher = "quarto";
          version = "1.59.0";
          sha256 = "0piqxdf73n34pj58wf4wz4i2mkmrhg7xn96zhzaiqs1613b8cjip";
        }

        # can't install it :(
        #{
        #  name = "ruff";
        #  publisher = "charliermash";
        #  version = "2022.1.13600349";
        #  sha256 = "sha256-Da9Anme6eoKLlkdYaeLFDXx0aQgrtepuUnw2jEPXCVr=";
        #}
      ];
  };
}
