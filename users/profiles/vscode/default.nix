{pkgs, ...}: {
  programs.vscode = {
    enable = true;

    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    userSettings = {
      "telemetry.telemetryLevel" = "off";
      "quarto.mathjax.theme" = "dark";
      "files.trimTrailingWhitespace" = true;
      "git.mergeEditor" = true;
      "autoDocstring.docstringFormat" = "google-notypes";
      "editor.formatOnSave" = true;
      "python.analysis.diagnosticMode" = "workspace";
      "python.formatting.provider" = "black";
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
          version = "2023.10.0";
          sha256 = "07x1slkf2g02pxdgmnl4k43wa5vkh8csrz9vrralnz4d63i3b00b";
        }
        {
          name = "gitlens";
          publisher = "eamodio";
          version = "2023.3.2505";
          sha256 = "0a5gngckkyipy5a51b67rjs8qa8srixdsy499ryy4s17wwzi1phr";
        }
        {
          name = "vscode-github-actions";
          publisher = "github";
          version = "0.25.2";
          sha256 = "06x3bm7w2am6nwsg2s0gvlghp27jgadb61axv58q4ja9b4fq1xz1";
        }
        {
          name = "vscode-pull-request-github";
          publisher = "GitHub";
          version = "0.61.2023032418";
          sha256 = "1hb3p9p049h1wggw7imaa9gj2bl58xrb9hcglgkpf7qca396l8d4";
        }
        {
          name = "language-julia";
          publisher = "julialang";
          version = "1.45.1";
          sha256 = "1bid8p5i7sx6qigj0g3n5kl7v3kvgih54rrfplc7720sc7g9ybrw";
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
          version = "2023.5.10831011";
          sha256 = "011gcm4bfxpqlp655nrdlj9b7gybb6hj77s6225bciq2y058c49g";
        }
        {
          name = "jupyter";
          publisher = "ms-toolsai";
          version = "2023.3.1000851011";
          sha256 = "0v0frndcppk61sw6w3pdcl0bldin6si9k0hck0865d1g5niqz1sn";
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
          version = "0.287.0";
          sha256 = "1zn3hzw9laagrjgg943g5nzydxiljq93ckb270fw0bjmab7hqi0c";
        }
        {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.101.2023032415";
          sha256 = "0bzg9g3nxig3d359f248flybxry3nihq8l07r6i95jv5wr3h5svk";
        }
        {
          name = "cmake-tools";
          publisher = "ms-vscode";
          version = "1.14.20";
          sha256 = "0shzgys095c10vnlk8cqs5ds10iwmmh5kj4cccq6yqbxjgmxkblg";
        }
        {
          name = "cpptools";
          publisher = "ms-vscode";
          version = "1.15.1";
          sha256 = "0s1jvvdgvd5zb5wfxjar89w9q519nv5nks2zgc7f4mbhv1h5ikks";
        }
        {
          name = "vsliveshare";
          publisher = "ms-vsliveshare";
          version = "1.0.5834";
          sha256 = "0xh719xmacgyn59xvbl4isb5xvg5i11bjmqpqra5pm8niyyy59zq";
        }
        {
          name = "autodocstring";
          publisher = "njpwerner";
          version = "0.6.1";
          sha256 = "11vsvr3pggr6xn7hnljins286x6f5am48lx4x8knyg8r7dp1r39l";
        }
        {
          name = "quarto";
          publisher = "quarto";
          version = "1.78.0";
          sha256 = "1p45qhj1kpy8cv243afkwra8a67yy5rnp340l00zpygki8yba018";
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
