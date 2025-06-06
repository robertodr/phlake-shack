# Warning, this file is autogenerated by nix4vscode. Don't modify this manually.
{ pkgs, lib }:

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
      #"asvetliakov"."vscode-neovim" = vscode-utils.extensionFromVscodeMarketplace {
      #  name = "vscode-neovim";
      #  publisher = "asvetliakov";
      #  version = "1.18.22";
      #  sha256 = "180qshm1fhgj3yf4khxiaqsrb6s7b4i7vl0xfxvfwi3a30cmj94x";

      #};
      "eamodio"."gitlens" = vscode-utils.extensionFromVscodeMarketplace {
        name = "gitlens";
        publisher = "eamodio";
        version = "17.1.1";
        sha256 = "07lyd3s5g6w5piglqbsm808f620j1mc8lwbr4cm41gvpnkhnln46";

      };
      "github"."copilot" = vscode-utils.extensionFromVscodeMarketplace {
        name = "copilot";
        publisher = "github";
        version = "1.323.0";
        sha256 = "02jww3w58dfxzr9g2bcw7fn7k9pd6ab306xn8q071p77r7m2lc5d";

      };
      "github"."copilot-chat" = vscode-utils.extensionFromVscodeMarketplace {
        name = "copilot-chat";
        publisher = "github";
        version = "0.27.2";
        sha256 = "107d6xlwgd1949lj2f2d439b48s6jzdmc68l9wsb1airvd04604z";

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
        version = "0.110.0";
        sha256 = "09xc0bfbb64865ayzm18ijmn3f2h2qh4527243v85lv602xgm05f";

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
        version = "1.29.6";
        sha256 = "17gw0y75bfyvn0kjn1fbzsp15g1hswamk8v4wnp739rimi5jwx4h";

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
        version = "0.413.0";
        sha256 = "11xl1550xif5mnq0crkw85ycsi79drym1ya6hb8y9kz8520vif1q";

      };
      "ms-vscode-remote"."remote-ssh" = vscode-utils.extensionFromVscodeMarketplace {
        name = "remote-ssh";
        publisher = "ms-vscode-remote";
        version = "0.120.0";
        sha256 = "0p8rx867pdwyzx1bcjf069zzi8nfvhb3bjv7q3v8dd43l4n2dmhg";

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
        version = "1.30.0";
        sha256 = "0z0hg06p8fvggz4r4yyws47hj3nx70my57isqdlms5y230kb2qyb";

      };
    } (lib.attrsets.optionalAttrs (isLinux && (isi686 || isx86_64)) { }))
    (lib.attrsets.optionalAttrs (isLinux && (isAarch32 || isAarch64)) { })
  ) (lib.attrsets.optionalAttrs (isDarwin && (isi686 || isx86_64)) { }))
  (lib.attrsets.optionalAttrs (isDarwin && (isAarch32 || isAarch64)) { })
