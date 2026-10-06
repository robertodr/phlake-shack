{
  config,
  lib,
  pkgs,
  ...
}:
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
    # Activation gates console login; do not fetch mutable npm updates at boot.
    # Update explicitly after login with: pi update --extensions
    activation.updatePiExtensions = lib.mkForce (lib.hm.dag.entryAfter [ "writeBoundary" ] "");
  };

  services.ssh-agent.enable = true;

  programs.git.settings.user.signingkey = "${config.home.homeDirectory}/.ssh/git_signing_ed25519";

  # Distinguish the headless host in both local and SSH terminals.
  programs.starship.settings = {
    format = lib.mkForce ''
      [┌─](bold blue) $username$hostname:$directory
      [│](bold blue) $time \[$nix_shell$python$rust\]
      [└─](bold blue) \($git_branch$git_state$git_status\) $character'';
    username.style_user = lib.mkForce "bold cyan";
    hostname.format = lib.mkForce "[@](bold cyan)[$hostname](bold cyan)";
    directory.style = lib.mkForce "bold #5fafff";
    character.success_symbol = lib.mkForce "[>](bold cyan) ";
  };
}
