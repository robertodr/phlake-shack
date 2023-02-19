{pkgs, ...}: {
  programs.vscode = {
    enable = true;

    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    userSettings = {
      "telemetry.telemetryLevel" = "off";
      "quarto.mathjax.theme" = "dark";
      "files.trimTrailingWhitespace" = "true";
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
          version = "2023.6.0";
          sha256 = "sha256-TomJMcL/JYFQkrbWGimUYJlvEJxDzQH656R9Z1HiQN4=";
        }
        {
          name = "gitlens";
          publisher = "eamodio";
          version = "2023.2.304";
          sha256 = "1is0mfxl2qyf00i5p80nh6bfaz0a0sa4gvdr32fjbizgnz9465k8";
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
          version = "2023.3.10341119";
          sha256 = "1nplfvjx7arjw1ljy8rfw7vz04y5l5rlzryxjwxd7dq5nz3hwda9";
        }
        {
          name = "jupyter";
          publisher = "ms-toolsai";
          version = "2023.2.1000360234";
          sha256 = "0a06rzjizr8h1vyczvk1aysparf0xhk70iw86i49f6pw72pa52wn";
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
          version = "0.276.0";
          sha256 = "1973x9r4k2b8919wzpash17c58csv2d6k953szfk3gcrvx8xdffq";
        }
        {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.97.2023020215";
          sha256 = "0iy0s4whm19r59a5x03phk71ryf9arbmpi5qasa44ymnhhhl1a4w";
        }
        {
          name = "cmake-tools";
          publisher = "ms-vscode";
          version = "1.14.6";
          sha256 = "1cip4250332ywipvbd9h6xqrr861n22ri7acw00i7ximvghvnf49";
        }
        {
          name = "cpptools";
          publisher = "ms-vscode";
          version = "1.14.1";
          sha256 = "02c17s2w6bxv5gdpjvx2fks7ci256nbjm57cavrxycwc4appr8xh";
        }
        {
          name = "vsliveshare";
          publisher = "ms-vsliveshare";
          version = "1.0.5828";
          sha256 = "1myk9njk2l3r989vf6m1x7ff0ygkrpkf2i5h2ba3zczp4sp8fh6d";
        }
        {
          name = "quarto";
          publisher = "quarto";
          version = "1.61.0";
          sha256 = "0sr5y2w7cfcyhjmszcmphx321d618snh8dbqvr8ydv7d8j92891k";
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
