{
  pkgs,
  lib,
}: let
  inherit (pkgs.stdenv) isDarwin isLinux isi686 isx86_64 isAarch32 isAarch64;
  vscode-utils = pkgs.vscode-utils;
  merge = lib.attrsets.recursiveUpdate;
in
  merge
  (merge
    (merge
      (merge
        {
          "ms-azuretools"."vscode-docker" = vscode-utils.extensionFromVscodeMarketplace {
            name = "vscode-docker";
            publisher = "ms-azuretools";
            version = "1.29.3";
            sha256 = "1j35yr8f0bqzv6qryw0krbfigfna94b519gnfy46sr1licb6li6g";
          };
          "eamodio"."gitlens" = vscode-utils.extensionFromVscodeMarketplace {
            name = "gitlens";
            publisher = "eamodio";
            version = "2024.11.2604";
            sha256 = "1i8adhy0n6j3hf8psa7jxhizrw2absn4a5x8i0q6y58cic7y8026";
          };
          "ms-vscode-remote"."remote-containers" = vscode-utils.extensionFromVscodeMarketplace {
            name = "remote-containers";
            publisher = "ms-vscode-remote";
            version = "0.391.0";
            sha256 = "1rw3k3slk7c815kbjbnbjdwgrskkhcjrqbdgyja8bydws10bxjcp";
          };
          "github"."vscode-pull-request-github" = vscode-utils.extensionFromVscodeMarketplace {
            name = "vscode-pull-request-github";
            publisher = "github";
            version = "0.101.2024111810";
            sha256 = "012dm1x7wlhqa4dcb364m7b52g6mi9i2kvzb7vq0j9kxrlbwmh5c";
          };
          "ms-vscode-remote"."remote-ssh" = vscode-utils.extensionFromVscodeMarketplace {
            name = "remote-ssh";
            publisher = "ms-vscode-remote";
            version = "0.116.2024111219";
            sha256 = "1vwkfc4iwvqrcs3r0gkz2aikl8dgzdznasajfs489da8vi3zc30v";
          };
          "github"."copilot" = vscode-utils.extensionFromVscodeMarketplace {
            name = "copilot";
            publisher = "github";
            version = "1.245.1227";
            sha256 = "0x28ccvfgc7faf9g8qf6qz8g7s42xw89qh8ivbcmaas4il6c0z4f";
          };
          "ms-vsliveshare"."vsliveshare" = vscode-utils.extensionFromVscodeMarketplace {
            name = "vsliveshare";
            publisher = "ms-vsliveshare";
            version = "1.0.5941";
            sha256 = "0qpbq4j2mz1cv10bn7kdipyjany7j5zw71p3djp2dz9a5i1pmcxk";
          };
          "github"."copilot-chat" = vscode-utils.extensionFromVscodeMarketplace {
            name = "copilot-chat";
            publisher = "github";
            version = "0.23.2024102903";
            sha256 = "0qdg4jc7rykm5a0ba9n2bflfm0dw0cja8j8sfvdnv2xqppww2sql";
          };
          "oderwat"."indent-rainbow" = vscode-utils.extensionFromVscodeMarketplace {
            name = "indent-rainbow";
            publisher = "oderwat";
            version = "8.3.1";
            sha256 = "0iwd6y2x2nx52hd3bsav3rrhr7dnl4n79ln09picmnh1mp4rrs3l";
          };
          "aaron-bond"."better-comments" = vscode-utils.extensionFromVscodeMarketplace {
            name = "better-comments";
            publisher = "aaron-bond";
            version = "3.0.2";
            sha256 = "15w1ixvp6vn9ng6mmcmv9ch0ngx8m85i1yabxdfn6zx3ypq802c5";
          };
          "vscodevim"."vim" = vscode-utils.extensionFromVscodeMarketplace {
            name = "vim";
            publisher = "vscodevim";
            version = "1.28.1";
            sha256 = "0cwml7z6gj2hi1hr9bzavg4zcij73lap9qgry3biv47pgwzn1gvj";
          };
          "gruntfuggly"."todo-tree" = vscode-utils.extensionFromVscodeMarketplace {
            name = "todo-tree";
            publisher = "gruntfuggly";
            version = "0.0.226";
            sha256 = "0yrc9qbdk7zznd823bqs1g6n2i5xrda0f9a7349kknj9wp1mqgqn";
          };
          "github"."vscode-github-actions" = vscode-utils.extensionFromVscodeMarketplace {
            name = "vscode-github-actions";
            publisher = "github";
            version = "0.27.0";
            sha256 = "0sk8cgnk4pyjxwfi3hr3qrajffvdncvq3xbjn73g3jz0ygakg7xi";
          };
          "adpyke"."codesnap" = vscode-utils.extensionFromVscodeMarketplace {
            name = "codesnap";
            publisher = "adpyke";
            version = "1.3.4";
            sha256 = "012sj4a65sr8014z4zpxqzb6bkj7pnhm4rls73xpwawk6hwal7km";
          };
          "mkhl"."direnv" = vscode-utils.extensionFromVscodeMarketplace {
            name = "direnv";
            publisher = "mkhl";
            version = "0.17.0";
            sha256 = "1n2qdd1rspy6ar03yw7g7zy3yjg9j1xb5xa4v2q12b0y6dymrhgn";
          };
        }
        (lib.attrsets.optionalAttrs (isLinux && (isi686 || isx86_64)) {}))
      (lib.attrsets.optionalAttrs (isLinux && (isAarch32 || isAarch64)) {}))
    (lib.attrsets.optionalAttrs (isDarwin && (isi686 || isx86_64)) {}))
  (lib.attrsets.optionalAttrs (isDarwin && (isAarch32 || isAarch64)) {})
