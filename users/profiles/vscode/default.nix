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
      pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "protein-viewer";
          publisher = "ArianJamasb";
          version = "0.1.0";
          sha256 = "1k5r491p4s3mymnbzjvjpkxnlvq9c4py3blbrwpf2ybjanwskjn6";
        }
        {
          name = "Nix";
          publisher = "bbenoist";
          version = "1.0.1";
          sha256 = "0zd0n9f5z1f0ckzfjr38xw2zzmcxg1gjrava7yahg5cvdcw6l35b";
        }
        {
          name = "ruff";
          publisher = "charliermarsh";
          version = "2023.5.10291638";
          sha256 = "sha256-231jttvt3v9NqagkntCOahFK2TtDGk7TPPqo7EzrgsQ=";
        }
        {
          name = "gitlens";
          publisher = "eamodio";
          version = "2023.1.3011";
          sha256 = "1q6n1xr7r53vw9f8bnf9x49s320r822f5xgivyq7cjhngz3csfaw";
        }
        {
          name = "language-julia";
          publisher = "julialang";
          version = "1.41.1";
          sha256 = "186lrckvzkyqvxmzi7yi9rhx5523rhah95ra3by049lsr9hkzzw7";
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
          name = "python";
          publisher = "ms-python";
          version = "2023.1.10271009";
          sha256 = "1q8big0c4w8r14lvrkp5l2y26c1fkb7ili647pgzgj1vwal0g0g4";
        }
        {
          name = "jupyter";
          publisher = "ms-toolsai";
          version = "2023.1.2000281008";
          sha256 = "0jykd8dqbp3q7fbjyc19yan3d24fg7mdf8m5bqddgayl48qbirqd";
        }
        {
          name = "jupyter-keymap";
          publisher = "ms-toolsai";
          version = "1.0.0";
          sha256 = "0wkwllghadil9hk6zamh9brhgn539yhz6dlr97bzf9szyd36dzv8";
        }
        {
          name = "remote-containers";
          publisher = "ms-vscode-remote";
          version = "0.274.0";
          sha256 = "0y7skjrs8bckw86zbc7f1npyhjdmn49p27j26fd8q9g53s8bm1xh";
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
          version = "1.14.4";
          sha256 = "08v6cbjl4sy2p6vay4g8rdg9ybh0wf6lragmirm17718rfyvykrv";
        }
        {
          name = "cpptools";
          publisher = "ms-vscode";
          version = "1.14.0";
          sha256 = "sha256-rnZqy94LedtULLm2i65usffnjDdWursxrd2oI1zTV5s=";
        }
        {
          name = "vsliveshare";
          publisher = "ms-vsliveshare";
          version = "1.0.5823";
          sha256 = "0sb6fm2z8cnz3da6wmljwi0fvfjkm9vvmb1xgqfwfn6qd3r2yi1b";
        }
        {
          name = "quarto";
          publisher = "quarto";
          version = "1.59.0";
          sha256 = "0piqxdf73n34pj58wf4wz4i2mkmrhg7xn96zhzaiqs1613b8cjip";
        }
        {
          name = "vim";
          publisher = "vscodevim";
          version = "1.24.3";
          sha256 = "02alixryryak80lmn4mxxf43izci5fk3pf3pcwy52nbd3d2fiwz1";
        }
      ];
  };
}
