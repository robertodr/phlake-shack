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

    activation = {
      createScreenshotsDir = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${config.xdg.userDirs.pictures}/Screenshots"
      '';
      createSopsAgeDir = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${config.xdg.configHome}/sops/age"
      '';
    };

    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    #
    # You can update Home Manager without changing this value. See
    # the Home Manager release notes for a list of state version
    # changes in each release.
    stateVersion = "24.11";

    sessionVariables = {
      EDITOR = "nvim";
      LESSHISTFILE = "${stateHome}/lesshst";
      SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
      XDG_SCREENSHOTS_DIR = "${config.xdg.userDirs.pictures}/Screenshots";
      QISKIT_IBM_TOKEN = ''$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."ibm-cloud/token".path})'';
    };

    # see: https://github.com/nix-community/home-manager/issues/3263#issuecomment-1505801395
    # this was introduced in commit e2f952d4e8b56e6edabd21f22a8ce2e3fb322971 to
    # get 1password commit signing up and running in vscode&emacs
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
      cdxgen
      clang-tools # TODO <- needed here?
      cmake-language-server
      cyclonedx-cli
      delta # TODO <- this or difftastic?
      flamegraph
      git-extras
      global
      gnumake
      hotspot
      jless
      linuxPackages.perf
      meld
      perf-tools
      universal-ctags

      nix-prefetch
      nix-prefetch-github
      nix-prefetch-scripts
      nix-tree
      nix-update
      pkgsUnstable.nixfmt
      nixpkgs-lint

      python3
      python3Packages.pip
      python3Packages.keyring
      pkgsUnstable.uv

      asciinema
      evince
      ferdium
      ffmpeg
      ghostscript
      gimp
      imagemagick
      inkscape
      insync
      nomacs
      pdf2svg
      pdftk
      pika-backup
      playerctl
      poppler
      spotify
      vlc
      wordnet
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

  xdg = {
    configFile = {
      "electron-flags.conf".text = ''
        --enable-features=UseOzonePlatform
        --ozone-platform=wayland
        --wayland-text-input-version=3
      '';
    };
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
      "ghostty"
      "git"
      "gpg-agent"
      "htop"
      "jq"
      "kitty"
      "mako"
      "man"
      "network-manager-applet"
      "nh"
      "ripgrep"
      "ssh"
      "starship"
      "tealdeer"
      "visidata"
      "yazi"
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
      "onlyoffice"
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
      "wayland/niri"
      "wlogout"
    ]
  );

  sops = {
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    secrets = {
      "ibm-cloud/token" = {
        sopsFile = ../../secrets/ibm-cloud.yaml;
        path = "${config.xdg.configHome}/ibm-cloud.txt";
      };
    };
  };
}
