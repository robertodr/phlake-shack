{pkgs, ...}: {
  programs.vscode = {
    enable = true;

    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    userSettings = {
      "autoDocstring.docstringFormat" = "google-notypes";
      "editor.formatOnSave" = true;
      "extensions.autoCheckUpdates" = false;
      "files.trimTrailingWhitespace" = true;
      "git.mergeEditor" = true;
      "python.analysis.diagnosticMode" = "openFilesOnly";
      "python.formatting.provider" = "black";
      "quarto.mathjax.theme" = "dark";
      "telemetry.telemetryLevel" = "off";
      "update.mode" = "none";
      "cmake.configureOnOpen" = true;
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
          version = "0.60.0";
          sha256 = "sha256-VAoKNRYrzUXUQSDAX8NM17aknCUxMRsTRd5adQu+w/s=";
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
          version = "2023.4.0";
          sha256 = "sha256-owQmPlTgcX6NmtfRrd9i8DMflP65smAmsedPYqV/Gzg=";
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
        {
          name = "cpptools-extension-pack";
          publisher = "ms-vscode";
          version = "1.3.0";
          sha256 = "sha256-rHST7CYCVins3fqXC+FYiS5Xgcjmi7QW7M4yFrUR04U=";
        }
        {
          name = "cpptools";
          publisher = "ms-vscode";
          version = "1.15.4";
          sha256 = "sha256-ldgbAaJ4sVFMEXuhXbMBwSvpsym4XOQ0//JGeOVHpyY=";
        }
        {
          name = "cpptools-themes";
          publisher = "ms-vscode";
          version = "2.0.0";
          sha256 = "sha256-YWA5UsA+cgvI66uB9d9smwghmsqf3vZPFNpSCK+DJxc=";
        }
        {
          name = "cmake-tools";
          publisher = "ms-vscode";
          version = "1.15.7";
          sha256 = "sha256-kkD2mLaQoHOWwUz3IKuSwJxwlHCL5gaHeIAgAoy5n8s=";
        }
        {
          name = "vscode-docker";
          publisher = "ms-azuretools";
          version = "1.24.0";
          sha256 = "sha256-zZ34KQrRPqVbfGdpYACuLMiMj4ZIWSnJIPac1yXD87k=";
        }
        {
          name = "vscode-pylance";
          publisher = "ms-python";
          version = "2023.6.11";
          sha256 = "sha256-beRcnS5FcQXQ9LHLclMdxEDcNHPWLXCqlJZCQdBWetQ=";
        }
        {
          name = "jupyter";
          publisher = "ms-toolsai";
          version = "2023.5.1001582324";
          sha256 = "sha256-EyN3WkUCcPokT20fwHvQt7v0t+gNLhm/oehML+XDxUY=";
        }
      ];
  };
}
