{ config, ... }:
{
  imports = [
    ../profiles/base
    ../profiles/development
  ];
  home = {
    username = "roberto";
    homeDirectory = "/Users/roberto";
    stateVersion = "26.05";
  };
  programs.git.settings.user.signingkey = "${config.home.homeDirectory}/.ssh/git_signing_ed25519";
}
