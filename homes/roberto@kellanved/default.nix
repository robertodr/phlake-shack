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
    };

    # see: https://github.com/nix-community/home-manager/issues/3263#issuecomment-1505801395
    # this was introduced in commit e2f952d4e8b56e6edabd21f22a8ce2e3fb322971 to
    # get 1password commit signing up and running in vscode&emacs
    file.".profile".text = ''
      . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
    '';

    shell = {
      enableBashIntegration = true;
      enableFishIntegration = true;
    };

    shellAliases = {
      xopen = "xdg-open";
      df = "duf";
      du = "ncdu";
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
      procs
      duf
      ncdu

      freerdp
      iputils
      numbat
      openconnect
      openvpn
      rclone
      step-cli
      tealdeer

      autoconf
      automake
      awscli2
      cachix
      clang-tools # TODO <- needed here?
      cmake-language-server
      delta
      flamegraph
      git-extras
      global
      gnumake
      hotspot
      jless
      perf
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
      ferdium
      ffmpeg
      ghostscript
      gimp
      imagemagick
      inkscape
      insync
      nomacs
      papers
      pdf2svg
      pdftk
      pika-backup
      playerctl
      poppler
      showtime
      spotify
      winboat
      wordnet
      zoom-us
    ];
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
      "mako"
      "man"
      "network-manager-applet"
      "nh"
      "ripgrep"
      "satty"
      "ssh"
      "starship"
      "tealdeer"
      "visidata"
      "zoxide"
    ]
    # development
    ++ [
      "direnv"
      "emacs"
      "gh"
      "opencode"
      #"tmpi"
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
      #"texlive"
    ]
    # wm
    ++ [
      "clipse"
      "gammastep"
      "gtk"
      "hypridle"
      "hyprlock"
      "hyprpaper"
      #"shikane"
      "vicinae"
      "waybar"
      "wayland/niri"
      "wlogout"
    ]
  );

  systemd.user.services.lxqt-policykit-agent = {
    Unit = {
      Description = "lxqt-policykit-agent";
      Wants = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };
}
