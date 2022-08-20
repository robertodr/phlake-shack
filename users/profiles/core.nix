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

  #  grex #      <- Generate regexps from user-provided test cases.
  #  httpie #    <- Modern, user-friendly command-line HTTP client for the API era.
  #  pastel #    <- A command-line tool to generate, analyze, convert and manipulate colors
  #  tealdeer #  <- A very fast implementation of tldr in Rust.

  #  ## === Formatters ===

  #  treefmt # One CLI to format the code tree
  #];

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    PHLAKE_SHACK_DIR = config.lib.phlake-shack.fsPath;

    LESSHISTFILE = "$XDG_STATE_HOME/lesshst";
  };

  home.stateVersion = lib.mkForce "22.05";
}
