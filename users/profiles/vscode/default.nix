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
    };

    extensions = with pkgs.vscode-extensions;
      pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "ruff";
          publisher = "charliermarsh";
          version = "2023.30.0";
          sha256 = "sha256-i/gskJ/p6gl0B1a8ZGWMN/TSPqS5h/TEEljgPZ9D8tw=";
        }
        {
          name = "gitlens";
          publisher = "eamodio";
          version = "14.0.0";
          sha256 = "sha256-wVw72jNDN4BAuIcT5wDX9Or5wj7jF+cegDvz2P9plw4=";
        }
        {
          name = "vscode-github-actions";
          publisher = "github";
          version = "0.25.8";
          sha256 = "07m8nz676wcfy289mxv4zbrzh0j4hxa4gs4rga8c3ijm2zymdp1p";
        }
        {
          name = "vscode-pull-request-github";
          publisher = "GitHub";
          version = "0.67.2023063008";
          sha256 = "07hzdsw3iic7h4518ppyn56l7na044gkl1svnzjn4ig9hi8rr9bh";
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
          version = "1.25.2";
          sha256 = "1vy5q7zvh23gqfwc6nmgx1jy42hrkqb8y650zk6xybvkxaaadnmq";
        }
        {
          name = "python";
          publisher = "ms-python";
          version = "2023.13.11871009";
          sha256 = "1frz1gj8r12vjhklk15kwqlq6vlzapk4wb70z9dkxb4xd5f4iv1j";
        }
        {
          name = "vscode-pylance";
          publisher = "ms-python";
          version = "2023.7.11";
          sha256 = "15h0jhn003a83884hziclixhb2qvhppi29cjg50ph83zj3vd7x7i";
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
          version = "0.300.0";
          sha256 = "1rvccis4zgg8k3bnpd2vwd4c6ys337kafvmivlhs30b03pf168m8";
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
          version = "1.15.18";
          sha256 = "0kz97xjwpcp0v4wwa2wjkvnkgacjpr6xazjgsk5gii6ry8cgxdk0";
        }
        {
          name = "cpptools";
          publisher = "ms-vscode";
          version = "1.16.3";
          sha256 = "1ymcszw5lzmqv2khnm8q46q96hbdb0qljm5sxzqzhn5alx505v4h";
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
          version = "1.0.5873";
          sha256 = "1c5bqz267va6lkg2zrz99drypdskrhyq0573gpy06icfj5pdl1m7";
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
          version = "1.88.0";
          sha256 = "1wgf7srkmq7zqwwi9zwc0s2ajwdhbkwmlcpp7aihflp1i7nkkdzm";
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
