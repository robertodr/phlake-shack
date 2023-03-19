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
          version = "2023.3.1805";
          sha256 = "14dv5dg1abn9gm597xyzj97dyis30b18p1ycwwqa0v7abxxwvjdm";
        }
        {
          name = "vscode-pull-request-github";
          publisher = "GitHub";
          version = "0.61.2023031710";
          sha256 = "1zw95f7dci6yrrn41v3fg424vwvs89bpaqgca5ja0b9995n5h9nw";
        }
        {
          name = "language-julia";
          publisher = "julialang";
          version = "1.42.1";
          sha256 = "1kvydrxhjmczky1322m89cgzq8whld3fr9xsbb5abxlg04vrbr3p";
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
          version = "2023.5.10752340";
          sha256 = "04zhh6p5h3cgp2q6dq5rjrishmzj1ah0xf7f37fydrs0xgara183";
        }
        {
          name = "jupyter";
          publisher = "ms-toolsai";
          version = "2023.3.1000771902";
          sha256 = "0wypc8dxbxlfcfpckhcs4jwh2rdwip1lkblrs4f1lg9pwa88mn4r";
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
          version = "0.285.0";
          sha256 = "0bg336vwiwbbzpjm4g1gra7qdd7gch7d13h6iv7lnvbl1h9plyjh";
        }
        {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.99.2023031515";
          sha256 = "1pm1a4m1x9x6s4669jhl756acbzi608lqfzzhhhy7fvp8hjd1gjz";
        }
        {
          name = "cmake-tools";
          publisher = "ms-vscode";
          version = "1.14.17";
          sha256 = "08nk48kjxiz64ya8fx180bdvb3p726f1iycvb8hzgfzvlqcklcdx";
        }
        {
          name = "cpptools";
          publisher = "ms-vscode";
          version = "1.15.0";
          sha256 = "1skg7qy6phgkf9jdr8d9asfsg87nfpnrlnzhfwbaj5vr3q2r5ygx";
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
          version = "1.77.0";
          sha256 = "0d7ifqh699s10pd65kijnxi1r3wii3yj59mbfd6cazzzs0m6zl23";
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
