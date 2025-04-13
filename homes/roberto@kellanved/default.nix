{
  pkgs,
  pkgsUnstable,
  config,
  ...
}:
let
  inherit (config.home) username;
  inherit (config.lib.file) mkOutOfStoreSymlink;
  inherit (config.xdg)
    configHome
    dataHome
    stateHome
    ;

  hmLib = config.lib;

  mountDir = "${config.home.homeDirectory}/clouds/gdrive";
in
{
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

    # TODO I think there's quite some crap in this list of packages...
    packages = with pkgs; [
      ## === Sysadmin ===
      brightnessctl
      du-dust # <- Like du but more intuitive.
      procs # <- A modern replacement for ps.

      freerdp
      hyperfine
      iputils
      kooha
      numbat
      openconnect
      openvpn
      rclone
      step-cli
      tealdeer
      tokei

      autoconf
      automake
      awscli2
      cachix
      clang-tools # TODO <- needed here?
      cmake-language-server
      delta # TODO <- this or difftastic?
      flamegraph
      git-extras
      gitAndTools.git-annex
      gitAndTools.git-annex-remote-rclone
      gitAndTools.git-annex-utils
      global
      gnumake
      hotspot
      jless
      linuxPackages.perf
      meld
      perf-tools
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
      avogadro2
      drawio
      evince
      ferdium
      ffmpeg
      ghostscript
      gimp
      imagemagick
      inkscape
      joplin-desktop
      nomacs
      onedrive
      onlyoffice-bin
      pdf2svg
      pdftk
      pika-backup
      pkgsUnstable.typst
      playerctl
      poppler
      spotify
      thunderbird
      vlc
      wordnet
      xournalpp
      #zoom-us
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
          After = [ "graphical-session-pre.target" ];
          Description = "polkit-gnome-authentication-agent-1";
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 10;
          Type = "simple";
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
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
      hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
        # Source: https://gitlab.archlinux.org/archlinux/packaging/packages/sway/-/commit/87acbcfcc8ea6a75e69ba7b0c976108d8e54855b
        "org.freedesktop.impl.portal.Inhibit" = "none";
        "org.freedesktop.impl.portal.ScreenCast" = "hyprland";
        "org.freedesktop.impl.portal.Screenshot" = "hyprland";

        # gnome-keyring interfaces
        "org.freedesktop.impl.portal.Secret" = "gnome-keyring";

        # GTK interfaces
        "org.freedesktop.impl.portal.FileChooser" = "gtk";
        "org.freedesktop.impl.portal.AppChooser" = "gtk";
        "org.freedesktop.impl.portal.Print" = "gtk";
        "org.freedesktop.impl.portal.Notification" = "gtk";
        "org.freedesktop.impl.portal.Access" = "gtk";
        "org.freedesktop.impl.portal.Account" = "gtk";
        "org.freedesktop.impl.portal.Email" = "gtk";
        "org.freedesktop.impl.portal.DynamicLauncher" = "gtk";
        "org.freedesktop.impl.portal.Lockdown" = "gtk";
        "org.freedesktop.impl.portal.Settings" = "gtk";
        "org.freedesktop.impl.portal.Wallpaper" = "gtk";
      };
    };
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
      gnome-keyring
    ];
    configPackages = with pkgs; [ gnome-keyring ];
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
      "fastfetch"
      "fish"
      "fzf"
      "git"
      "gnome-keyring"
      "gpg-agent"
      "htop"
      "jq"
      "kitty"
      "mako"
      "man"
      "navi"
      "network-manager-applet"
      "ripgrep"
      "ssh"
      "starship"
      "tealdeer"
      "yazi"
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
      "texlive"
    ]
    # wm
    ++ [
      "clipse"
      "fuzzel"
      "gammastep"
      "gtk"
      "hypridle"
      "hyprlock"
      "hyprpaper"
      "shikane"
      "waybar"
      "wayland/hyprland"
      "wlogout"
    ]
  );

  sops = {
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    secrets."ibm-quantum/token" = {
      sopsFile = ../../secrets/qiskit_ibm_token.yaml;
    };
  };
}
