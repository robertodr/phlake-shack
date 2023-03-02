{pkgs, ...}: {
  programs.vscode = {
    enable = true;

    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    userSettings = {
      "telemetry.telemetryLevel" = "off";
      "quarto.mathjax.theme" = "dark";
      "files.trimTrailingWhitespace" = "true";
      "git.mergeEditor" = "true";
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
          version = "2023.9.10540339";
          sha256 = "178b39yzks7bjr4kxr3c8hxr5g6pd7k0pilnasxdvb4dbzvvpakk";
        }
        {
          name = "vscode-github-actions";
          publisher = "cschleiden";
          version = "0.24.4";
          sha256 = "0371rms5cq2s7kfbzx078bfp7lcyq3lnxp1hrw1wy5igz94lvicp";
        }
        {
          name = "gitlens";
          publisher = "eamodio";
          version = "2023.3.104";
          sha256 = "1xb4dcnm4isz23aaxz1hw17n06qq8m2c7kabgkd6d3aanxad7n49";
        }
        {
          name = "vscode-pull-request-github";
          publisher = "GitHub";
          version = "0.59.2023030109";
          sha256 = "076zy71fj088kw3lsnmjhja8v06wkls4rml4bkxr76wbjb649gh2";
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
          version = "0.6.38";
          sha256 = "1dyc1j1g1g6f05i2iqdafb29537sxhac20pd2sng7plzzjd74p3n";
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
          version = "2023.5.10602345";
          sha256 = "1x9xcqjjaqjffxbyvpvsh0j2ynxzcv6baamawzs3spkqfspjnrb8";
        }
        {
          name = "jupyter";
          publisher = "ms-toolsai";
          version = "2023.2.1000592019";
          sha256 = "1mv44abb2iynsqhw9xs375sgfgnkf0zjndpmbyxjairynidw24wj";
        }
        {
          name = "jupyter-keymap";
          publisher = "ms-toolsai";
          version = "1.1.0";
          sha256 = "1i3qjvw5mmj53ysp0vgnjs48191raxkycbhp5gsrg229wr3yvc4j";
        }
        {
          name = "remote-containers";
          publisher = "ms-vscode-remote";
          version = "0.281.0";
          sha256 = "1n0c7mr9pa5lvsc372vxx8j99ig0i90a56gjal96pqizmfi8ddpp";
        }
        {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.97.2023022415";
          sha256 = "0vrf83vj83wra4zaznx34icgni33bs083cqfr8kq6pw5snrz72sy";
        }
        {
          name = "cmake-tools";
          publisher = "ms-vscode";
          version = "1.14.14";
          sha256 = "1zykdn1vm1pgz842ld5g7jrm2vin9if47ja6xpq2mxn5j6bap1qv";
        }
        {
          name = "cpptools";
          publisher = "ms-vscode";
          version = "1.14.4";
          sha256 = "0wy29vpyxplxfqmaadxd2pcl6mciiaghrxvjp7n7irbbqnp8q1fy";
        }
        {
          name = "vsliveshare";
          publisher = "ms-vsliveshare";
          version = "1.0.5832";
          sha256 = "1saa615yrhqildlji3f3wsq87r5fdbamdi15hg377ssxxw5snsxw";
        }
        {
          name = "quarto";
          publisher = "quarto";
          version = "1.71.0";
          sha256 = "0fsa8dylbm2s5xzy8dmibkmh0349yrj78j20g2zkmmy6k9qxk68y";
        }
        {
          name = "vim";
          publisher = "vscodevim";
          version = "1.25.2";
          sha256 = "0j0li3ddrknh34k2w2f13j4x8s0lb9gsmq7pxaldhwqimarqlbc7";
        }
      ];
  };
}
