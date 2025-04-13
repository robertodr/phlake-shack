{
  config,
  lib,
  ...
}:
let
  inherit (config.lib.dag) entryAfter;
in
{
  programs.ssh = {
    enable = true;
    compression = false;
    controlMaster = "auto";
    controlPath = "~/.ssh/sockets/%r@%h-%p";
    controlPersist = "600s";
    serverAliveCountMax = 2;
    serverAliveInterval = 300;
    # read the host configurations from file
    extraConfig = ''
      Host * !*.cineca.it
          IdentityAgent "~/.1password/agent.sock"

      ${lib.fileContents ./ssh_config}
    '';
  };

  # create ~/.ssh/sockets if it doesn't already exist
  home.activation.createSshSocketsDir = entryAfter [ "writeBoundary" ] ''
    if [[ ! -d "$HOME/.ssh/sockets" ]]; then
      mkdir -p $HOME/.ssh/sockets
    fi
  '';
}
