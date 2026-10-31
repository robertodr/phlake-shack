{ config, lib, ... }:
{
  programs.ssh.includes = [ "~/.ssh/1Password/config" ];
  programs.ssh.extraConfig = lib.mkAfter ("\n" + builtins.readFile ./ssh_config_onepassword);
  home.sessionVariables.SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
  sshAuthSock.initialization = {
    bash = "export SSH_AUTH_SOCK=$HOME/.1password/agent.sock";
    fish = "set -x SSH_AUTH_SOCK $HOME/.1password/agent.sock";
  };
}
