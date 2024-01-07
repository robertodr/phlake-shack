{pkgs, ...}: {
  programs.vscode = {
    enable = true;

    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    mutableExtensionsDir = false;

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
      "workbench.sideBar.location" = "right";
    };

    extensions = with pkgs.vscode-extensions;
      pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "ruff";
          publisher = "charliermarsh";
          version = "2023.35.12491300";
          sha256 = "sha256-eygA0zYzK85YxCoe+SZAPT0OMEsk5xH6sX9L7rQprxQ=";
        }
        {
          name = "vscode-github-actions";
          publisher = "github";
          version = "0.26.2";
          sha256 = "16kp1yxs798jp8ffqq3ixm3pyz4f3wgdkdyjpjy94ppqp4aklixh";
        }
        {
          name = "direnv";
          publisher = "mkhl";
          version = "0.14.0";
          sha256 = "1ssh577b0fx1cnkj52fiy1x41lcf56vk85sq7yrlmkmy9gmfvrjg";
        }
        {
          name = "vscode-docker";
          publisher = "ms-azuretools";
          version = "1.26.0";
          sha256 = "0fsmyxi0iwr0qr9fl86hsfqw8qlj3s9dzp25smx778zcvqxwlha6";
        }
        {
          name = "python";
          publisher = "ms-python";
          version = "2023.13.11871009";
          sha256 = "1frz1gj8r12vjhklk15kwqlq6vlzapk4wb70z9dkxb4xd5f4iv1j";
        }
        {
          name = "jupyter";
          publisher = "ms-toolsai";
          version = "2023.6.1001861915";
          sha256 = "sha256-aTHa5nAixrE6iWg+3Rq8i98pMQzuu3rYBHqxN0JlPjo=";
        }
        {
          name = "remote-containers";
          publisher = "ms-vscode-remote";
          version = "0.310.0";
          sha256 = "sha256-F73jOBnvJHYWxFTXaDEw0G/wV5EkYle2me9dg+fuUPA=";
          #1rvccis8zgg8k3bnpd2vwd4c6ys337kafvmivlhs30b03pf168m8";
        }
        {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.103.2023062115";
          sha256 = "01fshvm2j4bx6ray75rap7yczhc52bnvpww65rg4kvdsabxr71v8";
        }
        {
          name = "cmake-tools";
          publisher = "ms-vscode";
          version = "1.16.3";
          sha256 = "1v2ricifr6hi62vlblcl8p469ss58shgnz3h42r4lka90988bjad";
        }
        {
          name = "cpptools";
          publisher = "ms-vscode";
          version = "1.17.5";
          sha256 = "1mkdsps8h7k9w3ps2vzr8xmxh0rf3m14wgy5skqhs0r8r31h801c";
        }
        {
          name = "cpptools-extension-pack";
          publisher = "ms-vscode";
          version = "1.3.0";
          sha256 = "11fk26siccnfxhbb92z6r20mfbl9b3hhp5zsvpn2jmh24vn96x5c";
        }
        {
          name = "cpptools-themes";
          publisher = "ms-vscode";
          version = "2.0.0";
          sha256 = "05r7hfphhlns2i7zdplzrad2224vdkgzb0dbxg40nwiyq193jq31";
        }
        {
          name = "vsliveshare";
          publisher = "ms-vsliveshare";
          version = "1.0.5883";
          sha256 = "1zgjz25s1x1n93va7xbadmfjkqr2rahsrhpiw22xsshvswh4pp04";
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
          version = "1.97.0";
          sha256 = "00qvw3hqzca5yq1ndyrdwbkvddq4sc6zabxlq1plix6rvc9m184x";
        }
        {
          name = "vim";
          publisher = "vscodevim";
          version = "1.25.2";
          sha256 = "0j0li3ddrknh34k2w2f13j4x8s0lb9gsmq7pxaldhwqimarqlbc7";
        }
        {
          name = "gti-vscode";
          publisher = "Graphite";
          version = "0.2.2";
          sha256 = "sha256-0TCN95DegDNnEKm+Ptx9AXM6tecFX/PY0dO+Xzhslgo=";
        }
      ];
  };
}
