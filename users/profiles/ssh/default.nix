{ lib, ... }:

{
  programs.ssh = {
    enable = true;
    compression = false;
    serverAliveInterval = 300;
    serverAliveCountMax = 2;
    controlMaster = "auto";
    controlPath = "~/.ssh/sockets/%r@%h-%p";
    controlPersist = 600;
    extraConfig = lib.fileContents ("./ssh_config");
  };
}
