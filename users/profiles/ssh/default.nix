moduleArgs @ { config
, lib
, ...
}:

let
  inherit (config.lib.dag) entryAfter;
in
{
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
  home.activation.createSshSocketsDir =
    entryAfter [ "writeBoundary" ] ''
      if [[ ! -d "$HOME/.ssh/sockets" ]]; then
        mkdir $HOME/.ssh/sockets
      fi
    '';

  #home.file = {
  #  # FIXME what should this be if using Wayland?
  #  # also: is this at all needed? I'm using the Fish plugin...
  #  ".xprofile".text = ''
  #    eval $(/run/wrappers/bin/gnome-keyring-daemon --start --daemonize)
  #    export SSH_AUTH_SOCK
  #  '';
  #};
}
