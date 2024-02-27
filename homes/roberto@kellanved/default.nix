{
  lib,
  pkgs,
  config,
  nix-vscode-extensions,
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
  fonts.fontconfig.enable = true;
  manual = {
    html.enable = true;
    json.enable = true;
  };

  nixpkgs = {
    # you can add overlays here
    overlays = [
      inputs.nur.overlay
      # add overlays your own flake exports (from overlays and pkgs dir):
      #outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # you can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # configure your nixpkgs instance
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
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
    };

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
      du-dust #   <- Like du but more intuitive.
      procs #     <- A modern replacement for ps.

      tealdeer #  <- A very fast implementation of tldr in Rust.

      freerdp
      hyperfine
      iputils
      kooha
      openconnect
      # TODO openconnect-sso
      openvpn
      rclone
      remmina
      tokei
      shikane

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
      #graphite-cli
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
      #typst
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
      "tmpi"
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
    ++ [
      "fuzzel"
      "gammastep"
      "gtk"
      #"kanshi"  # TODO use shikane instead!
      "swayidle"
      "swaylock"
      "waybar"
      "wayland"
    ]
  );
}
