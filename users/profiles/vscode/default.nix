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
          version = "2023.24.0";
          sha256 = "sha256-674txw8/i23uI2ow32ux2WnqZ9sOClVCCLNjz3+G2Ic=";
        }
        {
          name = "gitlens";
          publisher = "eamodio";
          version = "2023.6.1705";
          sha256 = "sha256-1xAJho9uBkVUrhtu5mV27UeIKhrmYoZ7kEFSNsQTSlI=";
        }
        {
          name = "vscode-github-actions";
          publisher = "github";
          version = "0.25.7";
          sha256 = "sha256-MZrpaWe9PE+S4pRcSxLA417gQL0/oXvnZv+vSrb9nec=";
        }
        {
          name = "vscode-pull-request-github";
          publisher = "GitHub";
          version = "0.67.2023061509";
          sha256 = "sha256-pL58zD47O8pxSmsoSgO7gvmMNRfJPC63sLNqZbrZGJ4=";
        }
        {
          name = "direnv";
          publisher = "mkhl";
          version = "0.13.0";
          sha256 = "sha256-KdLJ7QTi9jz+JbbQuhXqyE3WV9oF+wyC/9ZJ/XTFOYc=";
        }
        {
          name = "vscode-docker";
          publisher = "ms-azuretools";
          version = "1.25.1";
          sha256 = "sha256-vEDmGrXgmEtZpsTdfYNL3MzuoJgh5zz+Z+ulMWI1EOQ=";
        }
        {
          name = "python";
          publisher = "ms-python";
          version = "2023.11.11671008";
          sha256 = "sha256-llfqAP5Dh9NdbdHHg2rvke6z0XZqpB6/REzx9LnCb1k=";
        }
        {
          name = "vscode-pylance";
          publisher = "ms-python";
          version = "2023.6.21";
          sha256 = "sha256-d3MYBTO3GlnbJlHmwUPTXKQKqmmWOzl+G+BoyduO7uA=";
        }
        {
          name = "jupyter";
          publisher = "ms-toolsai";
          version = "2023.6.1001691100";
          sha256 = "sha256-BxXvEWwKHhmHdp5NeA3agaEGrjKLIpUZ0CaXAINev30=";
        }
        {
          name = "remote-containers";
          publisher = "ms-vscode-remote";
          version = "0.296.0";
          sha256 = "sha256-Lnwan4jT5cQ/0ymd3skxS3cAhXZdwvKDRjzheX1Hqf4=";
        }
        {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.103.2023061415";
          sha256 = "sha256-600snUYti7HkLYK4CRTZsI20FZhTHOhxvZfMJLbzt4Y=";
        }
        {
          name = "cmake-tools";
          publisher = "ms-vscode";
          version = "1.15.13";
          sha256 = "sha256-DT1JtGFWYkQUnlZd0XXWwhlTXqLQOIhIb1DYj8p/zFg=";
        }
        {
          name = "cpptools";
          publisher = "ms-vscode";
          version = "1.16.0";
          sha256 = "sha256-bHrbdsGb9VW/R2rKGtTg6mov/BHJhRkHljAzIsvSpP4=";
        }
        {
          name = "cpptools-extension-pack";
          publisher = "ms-vscode";
          version = "1.3.0";
          sha256 = "sha256-rHST7CYCVins3fqXC+FYiS5Xgcjmi7QW7M4yFrUR04U=";
        }
        {
          name = "cpptools-themes";
          publisher = "ms-vscode";
          version = "2.0.0";
          sha256 = "sha256-YWA5UsA+cgvI66uB9d9smwghmsqf3vZPFNpSCK+DJxc=";
        }
        {
          name = "vsliveshare";
          publisher = "ms-vsliveshare";
          version = "1.0.5873";
          sha256 = "sha256-pwbabpGORQP8feMUgD3MU7frc0vp5y/epEbtY8THq7A=";
        }
        {
          name = "autodocstring";
          publisher = "njpwerner";
          version = "0.6.1";
          sha256 = "sha256-NI0cbjsZPW8n6qRTRKoqznSDhLZRUguP7Sa/d0feeoc=";
        }
        {
          name = "quarto";
          publisher = "quarto";
          version = "1.87.3";
          sha256 = "sha256-fmeQSxYwrPYTRN+DdOfXeo/lXh6LiiRGhRCo0WTcSQk=";
        }
        {
          name = "vim";
          publisher = "vscodevim";
          version = "1.25.2";
          sha256 = "sha256-hy2Ks6oRc9io6vfgql9aFGjUiRzBCS4mGdDO3NqIFEg=";
        }
      ];
  };
}
