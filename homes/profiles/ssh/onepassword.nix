{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.ssh.includes = [ "~/.ssh/1Password/config" ];
  programs.ssh.extraConfig = lib.mkAfter ("\n" + builtins.readFile ./ssh_config_onepassword);
  home.sessionVariables.SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
  sshAuthSock.initialization = {
    bash = "export SSH_AUTH_SOCK=$HOME/.1password/agent.sock";
    fish = "set -x SSH_AUTH_SOCK $HOME/.1password/agent.sock";
  };

  # On macOS the 1Password agent socket lives in its group container; expose it
  # at the same ~/.1password/agent.sock path used on Linux (as 1Password
  # recommends), so the settings above and ssh_config_onepassword stay shared.
  home.file.".1password/agent.sock" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  };
}
