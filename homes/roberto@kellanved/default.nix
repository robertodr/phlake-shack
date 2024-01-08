{
  lib,
  pkgs,
  config,
  nix-vscode-extensions,
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
  fonts.fontconfig.enable = true;

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

    extraOutputsToInstall = [
      "doc"
      "man"
      "devdoc"
      "info"
    ];

    sessionVariables = {
      EDITOR = "nvim";
    };

    shellAliases = {
      xopen = "xdg-open";
      du = "dust";
      ps = "procs";
      LESSHISTFILE = "$XDG_STATE_HOME/lesshst";
      SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
    };

    # TODO figure out how to handle this
    #file = {
    #  ".authinfo.gpg".source =
    #    mkOutOfStoreSymlink "${config.lib.phlake-shack.userConfigPath}/authinfo.gpg";
    #};

    # TODO I think there's quite some crap in this lists of packages...
    packages = with pkgs; [
      ## === Sysadmin ===
      du-dust #   <- Like du but more intuitive.
      procs #     <- A modern replacement for ps.

      tealdeer #  <- A very fast implementation of tldr in Rust.

      freerdp
      hyperfine
      iputils
      openconnect
      # TODO openconnect-sso
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
      graphite-cli
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

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  imports = map (x: ./.. + ("/profiles/" + x)) (
    # base
    [
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
      "man"
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
      #"emacs"
      #"tmpi" # TODO this needs tmux to work
      "gh"
      "vscode"
    ]
    # multimedia
    ++ [
      "firefox"
      "flameshot"
      "mpris-proxy"
    ]
    # office
    ++ [
      "newsboat"
      "pandoc"
      "texlive"
    ]
    # swaywm
    #++ [
    #  "gammastep"
    #  "gtk"
    #  #"kanshi"  # TODO use shikane instead!
    #  "swayidle"
    #  "swaylock"
    #  "waybar"
    #  "wayland"
    #]
  );
}
