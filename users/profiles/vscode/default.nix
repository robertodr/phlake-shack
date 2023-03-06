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
          version = "2023.9.10640400";
          sha256 = "1fr5s28rc7z6wz41blbyg4b4ibx1yw6fpi17knh01krr3fcm129d";
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
          version = "2023.3.604";
          sha256 = "1qb4kd1v8ppfdnldg979yjjhgbdm9b7jmp2189wggcax8s4cvqjy";
        }
        {
          name = "vscode-pull-request-github";
          publisher = "GitHub";
          version = "0.61.2023030611";
          sha256 = "0y0iv4sh9r3w7468p6l91mjgsw8dhjlw5zf9rq86v080rjj26p9n";
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
          version = "0.6.39";
          sha256 = "0ljmrgyd6sxd40gg0l82nxrp90dnaj20r1lc1wgmkv02v9qqrpq7";
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
          version = "2023.5.10651007";
          sha256 = "0gvkaxsiy12bry5q349skxagx6yivf86cmngg5i0nmhwq3i5cpln";
        }
        {
          name = "jupyter";
          publisher = "ms-toolsai";
          version = "2023.3.1000671010";
          sha256 = "0lbb3bz6iasz6vndwq9z56qalapp82m4zm3ilw13mi5q0lbaf9z4";
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
          version = "0.283.0";
          sha256 = "13b33xymj8ah7v4rmc1swj5w0jwr5ynwxjjbks75c76hnw6779id";
        }
        {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.99.2023030315";
          sha256 = "08i9zymgxl1ddqkq4gbz7qvbmnaaqf367n8qzc7srix512py669r";
        }
        {
          name = "cmake-tools";
          publisher = "ms-vscode";
          version = "1.14.15";
          sha256 = "1kils3rjkkl7xdc8wyw0df094syr0g3w8k5yzs4i0rs0n7bqd3hn";
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
