# Warning, this file is autogenerated by nix4vscode. Don't modify this manually.
{
  pkgs,
  lib,
}:
let
  inherit (pkgs.stdenv)
    isDarwin
    isLinux
    isi686
    isx86_64
    isAarch32
    isAarch64
    ;
  vscode-utils = pkgs.vscode-utils;
  merge = lib.attrsets.recursiveUpdate;
in
merge
  (merge (merge
    (merge {
      "aaron-bond"."better-comments" = vscode-utils.extensionFromVscodeMarketplace {
        name = "better-comments";
        publisher = "aaron-bond";
        version = "3.0.2";
        sha256 = "15w1ixvp6vn9ng6mmcmv9ch0ngx8m85i1yabxdfn6zx3ypq802c5";
      };
      "adpyke"."codesnap" = vscode-utils.extensionFromVscodeMarketplace {
        name = "codesnap";
        publisher = "adpyke";
        version = "1.3.4";
        sha256 = "012sj4a65sr8014z4zpxqzb6bkj7pnhm4rls73xpwawk6hwal7km";
      };
      "asvetliakov"."vscode-neovim" = vscode-utils.extensionFromVscodeMarketplace {
        name = "vscode-neovim";
        publisher = "asvetliakov";
        version = "1.18.19";
        sha256 = "0ppbi4hnxwv1d70z3dzd5awvn8nvphgiw42cq135b6jh6syb4v14";
      };
      "eamodio"."gitlens" = vscode-utils.extensionFromVscodeMarketplace {
        name = "gitlens";
        publisher = "eamodio";
        version = "17.0.2";
        sha256 = "0dhzghr46jqy4b3xy6ypcbb6x9iwspjzpq4zkca0ycfc7fzv179v";
      };
      "github"."copilot" = vscode-utils.extensionFromVscodeMarketplace {
        name = "copilot";
        publisher = "github";
        version = "1.301.0";
        sha256 = "18pnqrbp3y8jy1nxfkgfnvqm7v64spmraba0cx4wz6qbb5m9f8zr";
      };
      "github"."copilot-chat" = vscode-utils.extensionFromVscodeMarketplace {
        name = "copilot-chat";
        publisher = "github";
        version = "0.26.3";
        sha256 = "0pzafzkfc0hmgaipxvsb7zq9qs62cnsyi2flp7lcxmswshhgn1s0";
      };
      "github"."vscode-github-actions" = vscode-utils.extensionFromVscodeMarketplace {
        name = "vscode-github-actions";
        publisher = "github";
        version = "0.27.1";
        sha256 = "0pq97nl5h170r5cwsvps9z059lvj7a9aik2w84fnn3mjficrlwlq";
      };
      "github"."vscode-pull-request-github" = vscode-utils.extensionFromVscodeMarketplace {
        name = "vscode-pull-request-github";
        publisher = "github";
        version = "0.108.0";
        sha256 = "10p76fi8516gawjm9bvxgdw1val4mwrbmf3z7b7qld7kr5rlzlqq";
      };
      "gruntfuggly"."todo-tree" = vscode-utils.extensionFromVscodeMarketplace {
        name = "todo-tree";
        publisher = "gruntfuggly";
        version = "0.0.226";
        sha256 = "0yrc9qbdk7zznd823bqs1g6n2i5xrda0f9a7349kknj9wp1mqgqn";
      };
      "mkhl"."direnv" = vscode-utils.extensionFromVscodeMarketplace {
        name = "direnv";
        publisher = "mkhl";
        version = "0.17.0";
        sha256 = "1n2qdd1rspy6ar03yw7g7zy3yjg9j1xb5xa4v2q12b0y6dymrhgn";
      };
      "ms-azuretools"."vscode-docker" = vscode-utils.extensionFromVscodeMarketplace {
        name = "vscode-docker";
        publisher = "ms-azuretools";
        version = "1.29.5";
        sha256 = "1rj1bw16vw2zikpjgdm3bwdx1g1m76w4a4wn3q29ka7y5yl9a22r";
      };
      "ms-vscode"."cpptools-extension-pack" = vscode-utils.extensionFromVscodeMarketplace {
        name = "cpptools-extension-pack";
        publisher = "ms-vscode";
        version = "1.3.1";
        sha256 = "0dhn7d8q2736r763hnqwbwvml4w7k4hxbiy3v3903fvwsd8k9chx";
      };
      "ms-vscode-remote"."remote-containers" = vscode-utils.extensionFromVscodeMarketplace {
        name = "remote-containers";
        publisher = "ms-vscode-remote";
        version = "0.409.0";
        sha256 = "1d80pyai81nflvpn40x9ypk3jfiq0bycxpwrvsqnn4gmi5x4ksib";
      };
      "ms-vscode-remote"."remote-ssh" = vscode-utils.extensionFromVscodeMarketplace {
        name = "remote-ssh";
        publisher = "ms-vscode-remote";
        version = "0.119.0";
        sha256 = "0zqw0iq4z6q8p47x01cb3lp5pkmn0fdls9i3mg424da3z4qaxajb";
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
      "vscodevim"."vim" = vscode-utils.extensionFromVscodeMarketplace {
        name = "vim";
        publisher = "vscodevim";
        version = "1.29.0";
        sha256 = "1r29gd6na3gyc38v8ynmc2c46mi38zms1p87y65v9n2rj94pqx97";
      };
    } (lib.attrsets.optionalAttrs (isLinux && (isi686 || isx86_64)) { }))
    (lib.attrsets.optionalAttrs (isLinux && (isAarch32 || isAarch64)) { })
  ) (lib.attrsets.optionalAttrs (isDarwin && (isi686 || isx86_64)) { }))
  (lib.attrsets.optionalAttrs (isDarwin && (isAarch32 || isAarch64)) { })
