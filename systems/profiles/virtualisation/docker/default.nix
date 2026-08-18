{ pkgsUnstable, ... }:
{
  virtualisation = {
    docker = {
      enable = true;
      # Socket-activate rather than run the daemon permanently: containerd
      # shows up in the powertop wakeup list even when nothing is running.
      # The daemon starts on first use of the docker socket.
      # NOTE: containers with a restart policy no longer come back on boot.
      enableOnBoot = false;
      storageDriver = "btrfs";
      # see here: https://github.com/mamba-org/mamba/issues/2771#issuecomment-1691993724
      extraOptions = "--default-ulimit nofile=65536:65536";
    };
  };

  programs.singularity = {
    enable = true;
    enableSuid = true;
  };

  environment.systemPackages = [ pkgsUnstable.oras ];
}
