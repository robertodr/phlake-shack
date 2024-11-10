{
  lib,
  pkgs,
  config,
  inputs,
  outputs,
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

  mountDir = "${config.home.homeDirectory}/clouds/gdrive";
in {
  lib.phlake-shack = rec {
    fsPath = builtins.toString ./../..;
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

  manual = {
    html.enable = true;
    json.enable = true;
    manpages.enable = true;
  };

  home = {
    username = "roberto";
    homeDirectory = "/home/roberto";

    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    #
    # You can update Home Manager without changing this value. See
    # the Home Manager release notes for a list of state version
    # changes in each release.
    stateVersion = "23.11";

    sessionVariables = {
      EDITOR = "nvim";
      LESSHISTFILE = "${stateHome}/lesshst";
      SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
      XDG_SCREENSHOTS_DIR = "${config.xdg.userDirs.pictures}/Screenshots";
      QISKIT_IBM_TOKEN = ''$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."ibm-quantum/token".path})'';
    };

    # see: https://github.com/nix-community/home-manager/issues/3263#issuecomment-1505801395
    file.".profile".text = ''
      . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
    '';

    shellAliases = {
      xopen = "xdg-open";
      du = "dust";
      ps = "procs";
    };

    # TODO figure out how to handle this
    #file = {
    #  ".authinfo.gpg".source =
    #    mkOutOfStoreSymlink "${config.lib.phlake-shack.userConfigPath}/authinfo.gpg";
    #};

    # TODO I think there's quite some crap in this lists of packages...
    packages = with pkgs; [
      ## === Sysadmin ===
      brightnessctl
      du-dust #   <- Like du but more intuitive.
      procs #     <- A modern replacement for ps.

      tealdeer #  <- A very fast implementation of tldr in Rust.

      freerdp
      hyperfine
      iputils
      kooha
      openconnect
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
      copier
      delta # TODO <- this or difftastic?
      flamegraph
      fx
      git-extras
      gitAndTools.git-annex
      gitAndTools.git-annex-remote-rclone
      gitAndTools.git-annex-utils
      global
      gnumake
      #graphite-cli
      hotspot
      linuxPackages.perf
      meld
      mob
      perf-tools
      unifdef
      universal-ctags

      alejandra
      niv
      nix-prefetch
      nix-prefetch-github
      nix-prefetch-scripts
      nix-tree
      nix-update
      nixpkgs-fmt
      nixpkgs-lint

      python3

      asciinema
      drawio
      evince
      gimp
      inkscape
      joplin-desktop
      nomacs
      onlyoffice-bin
      pdf2svg
      pdftk
      pkgs.unstable.ferdium
      playerctl
      spotify
      thunderbird
      pkgs.unstable.typst
      vlc
      wordnet
      xournalpp
      zoom-us
    ];
  };

  systemd.user = {
    services = {
      #paperpile-mount = import ./gdrive-rclone/paperpile.nix {inherit mountDir pkgs;};
      #concepts-mount = import ./gdrive-rclone/concepts.nix {inherit mountDir pkgs;};
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

  xdg.configFile."electron-flags.conf".text = ''
    --enable-features=UseOzonePlatform
    --ozone-platform=wayland
  '';

  xdg.portal = {
    enable = true;
    config = {
      common = {
        default = ["hyprland"];
      };
      hyprland = {
        default = ["gtk" "hyprland"];
      };
    };
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
    xdgOpenUsePortal = true;
  };

  programs = {
    # let Home Manager install and manage itself.
    home-manager.enable = true;
  };

  imports = map (x: ./.. + ("/profiles/" + x)) (
    # base
    [
      "atuin"
      "bat"
      "blueman-applet"
      "bottom"
      "eza"
      "fish"
      "fzf"
      "git"
      "gnome-keyring"
      "gpg-agent"
      "jq"
      "kitty"
      "mako"
      "man"
      "navi"
      "ripgrep"
      "ssh"
      "starship"
      "tealdeer"
      "udiskie"
      "zellij"
      "zoxide"
    ]
    # development
    ++ [
      "direnv"
      "emacs"
      "tmpi"
      "gh"
      "vscode"
    ]
    # multimedia
    ++ [
      "firefox"
      "mpris-proxy"
      "playerctld"
    ]
    # office
    ++ [
      "newsboat"
      "pandoc"
      # not really using latex locally, but I can keep the code to enable it
      #"texlive"
    ]
    # swaywm
    ++ [
      "fuzzel"
      "gammastep"
      "gtk"
      "waybar"
      "wlogout"
      "hypridle"
      "hyprlock"
      "wayland/hyprland"
      "shikane"
    ]
  );

  sops = {
    age.sshKeyPaths = ["${config.home.homeDirectory}/.ssh/id_ed25519"];
    secrets."ibm-quantum/token" = {
      sopsFile = ../../secrets/qiskit_ibm_token.yaml;
    };
  };
}
