{ config, pkgs, ... }:
{
  imports = [
    ../profiles/base
    ../profiles/development
  ];

  home = {
    username = "roberto";
    homeDirectory = "/home/roberto";
    stateVersion = "26.05";
    packages = [ pkgs.tmux ];
  };

  services.ssh-agent.enable = true;

  programs.git.settings.user.signingkey = "${config.home.homeDirectory}/.ssh/git_signing_ed25519";
}
