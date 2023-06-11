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

      SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
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

      autoconf
      automake
      awscli2
      cachix
      clang-tools # TODO <- needed here?
      cmake-language-server
      delta # TODO <- this or difftastic?
      flamegraph
      fx
      git-extras
      gitAndTools.git-annex
      gitAndTools.git-annex-remote-rclone
      gitAndTools.git-annex-utils
      global
      gnumake
      linuxPackages.perf
      meld
      perf-tools
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
      typst
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
      # needed to get 1password to use system authentication correctly:
      # https://1password.community/discussion/comment/634787/#Comment_634787
      polkit-gnome-authentication-agent-1 = {
        Unit = {
          After = ["graphical-session-pre.target"];
          Description = "polkit-gnome-authentication-agent-1";
          PartOf = ["graphical-session.target"];
        };

        Service = {
          ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 10;
          Type = "simple";
        };

        Install = {
          WantedBy = ["graphical-session.target"];
        };
      };
    };
  };
}
