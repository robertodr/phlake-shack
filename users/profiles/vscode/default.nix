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
          version = "2023.2.2404";
          sha256 = "0a68l749q0rb1j6472ddmj9hsf1aq7vqllygvkw765x0gkjrbvbk";
        }
        {
          name = "vscode-pull-request-github";
          publisher = "GitHub";
          version = "0.59.2023022411";
          sha256 = "1k793nf639dc55n4p99gslzwn0y5f2rzjzbqq60sgbxwpzky61kz";
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
          version = "2023.3.10551009";
          sha256 = "0l24gsm19sdxiddd2lwl057ppnzxrz28mvp8qxbpmx1np446xx4w";
        }
        {
          name = "jupyter";
          publisher = "ms-toolsai";
          version = "2023.2.1000561009";
          sha256 = "04z4ykkzdnan0dwmbcd8s4snc76asm2y9mzpdamazwhvrw56fwc7";
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
          version = "0.281.0";
          sha256 = "1n0c7mr9pa5lvsc372vxx8j99ig0i90a56gjal96pqizmfi8ddpp";
        }
        {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.97.2023022015";
          sha256 = "1ffqy4p36k334crkr5qx4bzxw8d6h21y52y7w2n8wkh6zidg4c8j";
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
          version = "1.14.3";
          sha256 = "16mc63k0a0fr6f6nm3cz87c3s8p3hpa02bp9915zf1crwfx874z4";
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
          version = "1.69.0";
          sha256 = "0j9qkv21j6shsg13ka2ip8ya6mmin0xwac4ljabciwf7iq8j9xs0";
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
