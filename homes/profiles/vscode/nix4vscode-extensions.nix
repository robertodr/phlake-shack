{ pkgs, lib }:

let
  inherit (pkgs.stdenv) isDarwin isLinux isi686 isx86_64 isAarch32 isAarch64;
  vscode-utils = pkgs.vscode-utils;
  merge = lib.attrsets.recursiveUpdate;
in
merge
  (merge
    (merge
      (merge
      {
        "flox"."flox" = vscode-utils.extensionFromVscodeMarketplace {
          name = "flox";
          publisher = "flox";
          version = "0.0.1";
          sha256 = "1hx0szzak8b7gi4ixb771dkxv4i8f4i4in1ajsxrps66602hb9gj";
        };
        "adpyke"."codesnap" = vscode-utils.extensionFromVscodeMarketplace {
          name = "codesnap";
          publisher = "adpyke";
          version = "1.3.4";
          sha256 = "012sj4a65sr8014z4zpxqzb6bkj7pnhm4rls73xpwawk6hwal7km";
        };
        "ms-azuretools"."vscode-docker" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-docker";
          publisher = "ms-azuretools";
          version = "1.29.4";
          sha256 = "1nhrp43gh4pwsdy0d8prndx2l0mrczf1kirjl1figrmhcp7h4q4g";
        };
        "ms-vscode-remote"."remote-ssh" = vscode-utils.extensionFromVscodeMarketplace {
          name = "remote-ssh";
          publisher = "ms-vscode-remote";
          version = "0.118.2025020720";
          sha256 = "1misizc4hjg7agryrh0wy28q5wv99nrz43b98bvdhl9vv0p3bbvz";
        };
        "eamodio"."gitlens" = vscode-utils.extensionFromVscodeMarketplace {
          name = "gitlens";
          publisher = "eamodio";
          version = "2025.2.804";
          sha256 = "04kf98qy5vsh16nn4ydrl8nb47hbwafpjcfj2qrl7xvf9jshw2bb";
        };
        "ms-vsliveshare"."vsliveshare" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vsliveshare";
          publisher = "ms-vsliveshare";
          version = "1.0.5948";
          sha256 = "0rhwjar2c6bih1c5w4w8gdgpc6f18669gzycag5w9s35bv6bvsr8";
        };
        "ms-vscode"."cpptools-extension-pack" = vscode-utils.extensionFromVscodeMarketplace {
          name = "cpptools-extension-pack";
          publisher = "ms-vscode";
          version = "1.3.0";
          sha256 = "11fk26siccnfxhbb92z6r20mfbl9b3hhp5zsvpn2jmh24vn96x5c";
        };
        "aaron-bond"."better-comments" = vscode-utils.extensionFromVscodeMarketplace {
          name = "better-comments";
          publisher = "aaron-bond";
          version = "3.0.2";
          sha256 = "15w1ixvp6vn9ng6mmcmv9ch0ngx8m85i1yabxdfn6zx3ypq802c5";
        };
        "ms-vscode-remote"."remote-containers" = vscode-utils.extensionFromVscodeMarketplace {
          name = "remote-containers";
          publisher = "ms-vscode-remote";
          version = "0.398.0";
          sha256 = "06z9rwljxqf0hpj1qbila49ixymichvgpjxnc49fgi35pbbq936m";
        };
        "vscodevim"."vim" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vim";
          publisher = "vscodevim";
          version = "1.29.0";
          sha256 = "1r29gd6na3gyc38v8ynmc2c46mi38zms1p87y65v9n2rj94pqx97";
        };
        "oderwat"."indent-rainbow" = vscode-utils.extensionFromVscodeMarketplace {
          name = "indent-rainbow";
          publisher = "oderwat";
          version = "8.3.1";
          sha256 = "0iwd6y2x2nx52hd3bsav3rrhr7dnl4n79ln09picmnh1mp4rrs3l";
        };
        "github"."copilot-chat" = vscode-utils.extensionFromVscodeMarketplace {
          name = "copilot-chat";
          publisher = "github";
          version = "0.24.2025020602";
          sha256 = "04lwqbclqs9zjp39k4n0z5pjp5haqm9jm8jpng0xc8c4xhkq2rxj";
        };
        "github"."vscode-github-actions" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-github-actions";
          publisher = "github";
          version = "0.27.1";
          sha256 = "0pq97nl5h170r5cwsvps9z059lvj7a9aik2w84fnn3mjficrlwlq";
        };
        "gruntfuggly"."todo-tree" = vscode-utils.extensionFromVscodeMarketplace {
          name = "todo-tree";
          publisher = "gruntfuggly";
          version = "0.0.226";
          sha256 = "0yrc9qbdk7zznd823bqs1g6n2i5xrda0f9a7349kknj9wp1mqgqn";
        };
        "github"."copilot" = vscode-utils.extensionFromVscodeMarketplace {
          name = "copilot";
          publisher = "github";
          version = "1.266.1363";
          sha256 = "1n25cc34k98v4w5w8y9laz0kbxsg3470c6wy0rxji388jdyzz955";
        };
        "github"."vscode-pull-request-github" = vscode-utils.extensionFromVscodeMarketplace {
          name = "vscode-pull-request-github";
          publisher = "github";
          version = "0.105.2025020615";
          sha256 = "0r4khhwqfdapdzd7bh6lvwinhb63iqfl8ldb0z7sgpq430zsdj5q";
        };
        "mkhl"."direnv" = vscode-utils.extensionFromVscodeMarketplace {
          name = "direnv";
          publisher = "mkhl";
          version = "0.17.0";
          sha256 = "1n2qdd1rspy6ar03yw7g7zy3yjg9j1xb5xa4v2q12b0y6dymrhgn";
        };
      }
        (lib.attrsets.optionalAttrs (isLinux && (isi686 || isx86_64)) { }))
      (lib.attrsets.optionalAttrs (isLinux && (isAarch32 || isAarch64)) { }))
    (lib.attrsets.optionalAttrs (isDarwin && (isi686 || isx86_64)) { }))
  (lib.attrsets.optionalAttrs (isDarwin && (isAarch32 || isAarch64)) { })
