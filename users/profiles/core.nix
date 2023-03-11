{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.home) username;
  inherit (config.lib.file) mkOutOfStoreSymlink;
  inherit
    (config.xdg)
    configHome
    dataHome
    stateHome
    ;

  hmLib = config.lib;

  mountdir = "${config.home.homeDirectory}/clouds/gdrive";
in {
  lib.phlake-shack = rec {
    fsPath = "${configHome}/phlake-shack";
    userConfigPath = "${fsPath}/users/${username}/config";

    whoami = {
      firstName = "Roberto";
      lastName = "Di Remigio Eikås";
      fullName = "${whoami.firstName} ${whoami.lastName}";
      email = "roberto@totaltrash.xyz";
      githubUserName = "robertodr";
      pgpPublicKey = "E4FADFE6DFB29C6E";
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

    stateVersion = lib.mkForce "22.11";

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

      freerdp
      hyperfine
      iputils
      openconnect
      openconnect-sso
      openvpn
      rclone
      remmina
      tokei

      ansible
      ansible-lint
      autoconf
      automake
      awscli2
      bear
      cachix
      nodePackages.carbon-now-cli
      clang-tools # TODO <- needed here?
      cmake-language-server
      delta # TODO <- this or difftastic?
      dive
      #nur.repos.robertodr.enso
      flamegraph
      fx
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

      alejandra
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

      python3

      asciinema
      calibre
      drawio
      evince
      ferdium
      gimp
      inkscape
      joplin-desktop
      nomacs
      onlyoffice-bin
      pdf2svg
      pdftk
      playerctl
      spotify
      thunderbird
      vlc
      wordnet
      write_stylus
      xournalpp
      zoom-us
    ];
  };

  systemd.user = {
    services = {
      paperpile-mount = import ./gdrive-rclone/paperpile.nix {inherit mountdir pkgs;};
      concepts-mount = import ./gdrive-rclone/concepts.nix {inherit mountdir pkgs;};
    };
  };
}
