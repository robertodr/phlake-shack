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
            version = "2025.1.1804";
            sha256 = "1fgbx2lj0rpm0v6kwrmjq2nxbd3d68yxq3mlls6q8658nc22bn1j";
          };
          "ms-vscode"."cpptools-extension-pack" = vscode-utils.extensionFromVscodeMarketplace {
            name = "cpptools-extension-pack";
            publisher = "ms-vscode";
            version = "1.3.0";
            sha256 = "11fk26siccnfxhbb92z6r20mfbl9b3hhp5zsvpn2jmh24vn96x5c";
          };
          "ms-vscode-remote"."remote-containers" = vscode-utils.extensionFromVscodeMarketplace {
            name = "remote-containers";
            publisher = "ms-vscode-remote";
            version = "0.395.0";
            sha256 = "19m1n2k9bw0kms2adz9lngxbf2ymnf2571n663mwd9yxsjrrm2km";
          };
          "github"."vscode-pull-request-github" = vscode-utils.extensionFromVscodeMarketplace {
            name = "vscode-pull-request-github";
            publisher = "github";
            version = "0.103.2024121117";
            sha256 = "0k90870ra85np0dg19mx2blr1yg9i2sk25mx08bblqh0hh0s5941";
          };
          "github"."copilot" = vscode-utils.extensionFromVscodeMarketplace {
            name = "copilot";
            publisher = "github";
            version = "1.257.1319";
            sha256 = "1rqvfkh1jwmpi9rrr05mpwv1nys6ikj5diigbvzcx90cwvh7dw6w";
          };
          "ms-vscode-remote"."remote-ssh" = vscode-utils.extensionFromVscodeMarketplace {
            name = "remote-ssh";
            publisher = "ms-vscode-remote";
            version = "0.117.2025011723";
            sha256 = "05l0hjh51rak022ikg295ywhk5z0ia9sgmdchk6pqjnpdb61z137";
          };
          "github"."copilot-chat" = vscode-utils.extensionFromVscodeMarketplace {
            name = "copilot-chat";
            publisher = "github";
            version = "0.24.2024121201";
            sha256 = "14cs1ncbv0fib65m1iv6njl892p09fmamjkfyxrsjqgks2hisz5z";
          };
          "ms-vsliveshare"."vsliveshare" = vscode-utils.extensionFromVscodeMarketplace {
            name = "vsliveshare";
            publisher = "ms-vsliveshare";
            version = "1.0.5948";
            sha256 = "0rhwjar2c6bih1c5w4w8gdgpc6f18669gzycag5w9s35bv6bvsr8";
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
            version = "1.29.0";
            sha256 = "1r29gd6na3gyc38v8ynmc2c46mi38zms1p87y65v9n2rj94pqx97";
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
          "flox"."flox" = vscode-utils.extensionFromVscodeMarketplace {
            name = "flox";
            publisher = "flox";
            version = "1.0.0";
            sha256 = "02fhscybb6026250dg4sgmhl7cyh7zj28cw56vnzmy8jd212a48v";
          };
        }
        (lib.attrsets.optionalAttrs (isLinux && (isi686 || isx86_64)) {}))
      (lib.attrsets.optionalAttrs (isLinux && (isAarch32 || isAarch64)) {}))
    (lib.attrsets.optionalAttrs (isDarwin && (isi686 || isx86_64)) {}))
  (lib.attrsets.optionalAttrs (isDarwin && (isAarch32 || isAarch64)) {})
