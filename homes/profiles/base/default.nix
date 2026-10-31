{
  pkgs,
  config,
  ...
}:
let
  inherit (config.home) username;
  inherit (config.xdg) stateHome;
in
{
  lib.phlake-shack = rec {
    fsPath = builtins.toString ../../..;
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

  manual = {
    html.enable = true;
    json.enable = true;
    manpages.enable = true;
  };

  home = {
    username = "roberto";
    homeDirectory = "/home/roberto";

    activation.createSopsAgeDir = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.xdg.configHome}/sops/age"
    '';

    sessionVariables.LESSHISTFILE = "${stateHome}/lesshst";

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

    packages = with pkgs; [
      procs
      duf
      ncdu
      iputils
      numbat
      openconnect
      openvpn
      rclone
      step-cli
      tealdeer

      (aspellWithDicts (
        ds: with ds; [
          en
          en-computers
          en-science
          it
          nb
          nn
          sv
        ]
      ))

      delta
      enchant
      ffmpeg
      ghostscript
      imagemagick
      jless
      pdf2svg
      pdftk
      playerctl
      poppler
      wordnet
    ];
  };

  programs.home-manager.enable = true;

  imports = map (x: ./.. + ("/" + x)) [
    "atuin"
    "bat"
    "btop"
    "eza"
    "fastfetch"
    "fish"
    "fzf"
    "git"
    "gpg-agent"
    "helix"
    "htop"
    "jq"
    "man"
    "nh"
    "ripgrep"
    "ssh"
    "starship"
    "tealdeer"
    "visidata"
    "zoxide"
  ];
}
