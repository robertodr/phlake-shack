{ config
, lib
, pkgs
, ...
}:
let
  inherit (config.home) username;
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

    packages = with pkgs; [
      ## === Sysadmin ===
      du-dust #   <- Like du but more intuitive.
      procs #     <- A modern replacement for ps.

      grex #      <- Generate regexps from user-provided test cases.
      pastel #    <- A command-line tool to generate, analyze, convert and manipulate colors
      tealdeer #  <- A very fast implementation of tldr in Rust.

      arandr
      editorconfig-core-c
      freerdp
      graphviz
      hyperfine
      iputils
      openconnect
      openconnect-sso
      openvpn
      pulseaudio # to get pactl
      rclone
      remmina
      rofi-power-menu
      sqlite
      sshuttle
      tokei

      ansible
      ansible-lint
      autoconf
      automake
      bear
      cachix
      clang-tools # TODO <- needed here?
      cmake-language-server
      delta # TODO <- this or difftastic?
      dive
      flamegraph
      gcc # TODO <- needed here?
      git-along
      git-extras
      gitAndTools.git-annex
      gitAndTools.git-annex-remote-rclone
      gitAndTools.git-annex-utils
      global
      gnumake
      html-tidy
      linuxPackages.perf
      meld
      nodePackages.js-beautify
      perf-tools
      pijul
      pyright
      python3.pkgs.black
      python3.pkgs.isort
      shellcheck
      terraform
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

      haskellPackages.pandoc-crossref

      asciinema
      aspellWithDicts
      (ps: with ps; [ en it nb ])
      drawio
      evince
      ferdium
      gimp
      ispell
      joplin-desktop
      languagetool
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
