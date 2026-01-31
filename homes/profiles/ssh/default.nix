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
    enableDefaultConfig = false;
    matchBlocks."*" = {
      forwardAgent = false;
      addKeysToAgent = "no";
      compression = false;
      serverAliveInterval = 300;
      serverAliveCountMax = 3;
      hashKnownHosts = false;
      userKnownHostsFile = "~/.ssh/known_hosts";
      controlMaster = "auto";
      controlPath = "~/.ssh/sockets/%r@%h-%p";
      controlPersist = "600s";
    };
    # read the host configurations from file
    extraConfig = ''
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
