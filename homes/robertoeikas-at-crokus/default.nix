{ config, ... }:
{
  imports = [
    ../profiles/base
    ../profiles/development
  ];
  home = {
    username = "robertoeikas";
    homeDirectory = "/Users/robertoeikas";
    stateVersion = "26.05";
  };
  programs.git.settings.user.signingkey = "${config.home.homeDirectory}/.ssh/git_signing_ed25519";
}
