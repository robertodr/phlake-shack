moduleArgs @ {
  config,
  lib,
  ...
}: let
  inherit (config.lib.dag) entryAfter;
in {
  programs.ssh = {
    enable = true;
    compression = false;
    serverAliveInterval = 300;
    serverAliveCountMax = 2;
    controlMaster = "auto";
    controlPath = "~/.ssh/sockets/%r@%h-%p";
    controlPersist = "600s";
    extraConfig = lib.fileContents ./ssh_config;
  };

  # create ~/.ssh/sockets if it doesn't already exist
  home.activation.createSshSocketsDir = entryAfter ["writeBoundary"] ''
    if [[ ! -d "$HOME/.ssh/sockets" ]]; then
      mkdir -p $HOME/.ssh/sockets
    fi
  '';
}
