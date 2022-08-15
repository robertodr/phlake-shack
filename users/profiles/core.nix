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

  # FIXME review!
  #home.packages = with pkgs; [
  #  ## === Sysadmin ===

  #  du-dust #   <- Like du but more intuitive.
  #  entr #      <- Run arbitrary commands when files change
  #  lnav #      <- Log file navigator
  #  procs #     <- A modern replacement for ps.

  #  ## === `bat` and friends ===
  #  # A cat(1) clone with wings.

  #  bat

  #  # Bash scripts that integrate bat with various command line tools.
  #  # https://github.com/eth-p/bat-extras/
  #  bat-extras.batman #     <- Read system manual pages (man) using bat as the manual page formatter.
  #  bat-extras.batgrep #    <- Quickly search through and highlight files using ripgrep.
  #  bat-extras.batdiff #    <- Diff a file against the current git index, or display the diff between two files.
  #  bat-extras.batwatch #   <- Watch for changes in files or command output, and print them with bat.
  #  bat-extras.prettybat #  <- Pretty-print source code and highlight it with bat.

  #  grex #      <- Generate regexps from user-provided test cases.
  #  httpie #    <- Modern, user-friendly command-line HTTP client for the API era.
  #  pastel #    <- A command-line tool to generate, analyze, convert and manipulate colors
  #  tealdeer #  <- A very fast implementation of tldr in Rust.

  #  ## === Formatters ===

  #  treefmt # One CLI to format the code tree
  #];

  #programs.bash.enable = true;
  programs.fish.enable = true;
  programs.neovim.enable = true;
  #programs.zsh.enable = true;

  #programs.bat = {
  #  enable = true;
  #  config = {
  #    theme = "base16-256";
  #    map-syntax = [
  #      ".*ignore:Git Ignore"
  #      ".gitconfig.local:Git Config"
  #      "**/mx*:Bourne Again Shell (bash)"
  #      "**/completions/_*:Bourne Again Shell (bash)"
  #      ".vimrc.local:VimL"
  #      "vimrc:VimL"
  #    ];
  #  };
  #};

  #programs.bottom.enable = true;
  #programs.exa.enable = true;
  #programs.exa.enableAliases = true;
  #programs.jq.enable = true;
  #programs.less.enable = true;
  #programs.man.enable = true;
  ## N.B. This can slow down builds, but enables more manpage integrations
  ## across various tools. See the home-manager manual for more info.
  #programs.man.generateCaches = lib.mkDefault true;
  #programs.nix-index.enable = true;
  #programs.pandoc.enable = true;
  #programs.tealdeer.enable = true;
  #programs.zoxide.enable = true;

  #home.extraOutputsToInstall = ["/share/zsh"];

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    PHLAKE_SHACK_DIR = config.lib.phlake-shack.fsPath;

    LESSHISTFILE = "$XDG_STATE_HOME/lesshst";
  };

  home.stateVersion = lib.mkForce "22.05";
}
