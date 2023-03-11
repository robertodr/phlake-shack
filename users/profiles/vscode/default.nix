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
      "autoDocstring.docstringFormat" = "google-notypes";
      "editor.formatOnSave" = "true";
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
          version = "2023.9.10700555";
          sha256 = "0lm4bw710rg9qjw6p47qax50bzapx1z4sghd3fsbw4cwfg4734wf";
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
          version = "2023.3.1104";
          sha256 = "1j42hh6fpimnf5cgp68x0081sk7vz6gc57znkbc291bhkdgh5v8w";
        }
        {
          name = "vscode-pull-request-github";
          publisher = "GitHub";
          version = "0.61.2023030915";
          sha256 = "0njm4g7jz5q1iq9rw9n4016sy0cjx9781vjr64b9pk6czx891l5p";
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
          version = "2023.5.10681722";
          sha256 = "1hj2hbi68v7xcvl0c0i3xg9jm7bs5gwam2akmlfgqlrs9nbp0y4a";
        }
        {
          name = "jupyter";
          publisher = "ms-toolsai";
          version = "2023.3.1000711009";
          sha256 = "0nzd03sb1lhxzdma00wf4yyiwjf90v6hva89x72af2cgvw61fz5q";
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
          version = "1.73.0";
          sha256 = "0nnvc7p44zmpncbzvg7gqkqgzbpnvrqqlq8l84zlv1vvcpwa0f45";
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
