{ config
, lib
, pkgs
, ...
}:
let
  inherit (config.home) username;
  inherit (config.lib.file) mkOutOfStoreSymlink;
  inherit
    (config.xdg)
    configHome
    dataHome
    stateHome
    ;

  hmLib = config.lib;
in
{
  lib.phlake-shack = rec {
    fsPath = "${configHome}/phlake-shack";
    userConfigPath = "${fsPath}/users/${username}/config";

    whoami = {
      firstName = "Roberto";
      lastName = "Di Remigio Eikås";
      fullName = "${whoami.firstName} ${whoami.lastName}";
      email = "roberto@totaltrash.xyz";
      githubUserName = "robertodr";
      # FIXME
      #pgpPublicKey = "0x135EEDD0F71934F3";
    };

    emacs = {
      profilesBase = "emacs/profiles";
      profilesPath = "${userConfigPath}/${emacs.profilesBase}";
    };
  };

  fonts.fontconfig.enable = true;

  home = {
    sessionVariables = {
      PHLAKE_SHACK_DIR = config.lib.phlake-shack.fsPath;

      LESSHISTFILE = "$XDG_STATE_HOME/lesshst";
    };

    stateVersion = lib.mkForce "22.05";

    keyboard = {
      layout = "it(us),no";
      model = "pc105";
      options = [
        "grp:alt_shift_toggle"
      ];
    };

    extraOutputsToInstall = [
      "doc"
      "man"
      "devdoc"
      "info"
    ];

    # FIXME: use doom profile loader once issues are fixed upstream
    file = {
      ".authinfo.gpg".source =
        mkOutOfStoreSymlink "${config.lib.phlake-shack.userConfigPath}/authinfo.gpg";
    };

    packages = with pkgs; [
      ## === Sysadmin ===
      du-dust #   <- Like du but more intuitive.
      procs #     <- A modern replacement for ps.

      grex #      <- Generate regexps from user-provided test cases.
      pastel #    <- A command-line tool to generate, analyze, convert and manipulate colors
      tealdeer #  <- A very fast implementation of tldr in Rust.

      arandr
      freerdp
      hyperfine
      iputils
      openconnect
      #openconnect-sso # <- FIXME needs an overlay or something
      openvpn
      pulseaudio # to get pactl
      rclone
      remmina
      rofi-power-menu
      sshuttle
      tokei

      ansible
      ansible-lint
      autoconf
      automake
      awscli2
      bear
      cachix
      clang-tools # TODO <- needed here?
      cmake-language-server
      delta # TODO <- this or difftastic?
      dive
      flamegraph
      nur.repos.robertodr.git-along
      git-extras
      gitAndTools.git-annex
      gitAndTools.git-annex-remote-rclone
      gitAndTools.git-annex-utils
      global
      gnumake
      linuxPackages.perf
      meld
      perf-tools
      pijul
      unifdef
      universal-ctags

      niv
      nix-prefetch
      nix-prefetch-github
      nix-prefetch-scripts
      nix-top
      nix-tree
      nix-update
      nixos-container
      nixpkgs-fmt
      nixpkgs-lint

      python3Full

      julia-bin

      asciinema
      drawio
      evince
      ferdium
      gimp
      joplin-desktop
      libreoffice
      pdf2svg
      pdftk
      playerctl
      screenkey
      spotify
      vlc
      thunderbird
      wordnet
      write_stylus
      xournalpp
      zoom-us
    ];
  };
}
