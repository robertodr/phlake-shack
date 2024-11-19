{pkgs, ...}: {
  virtualisation = {
    docker = {
      enable = true;
      storageDriver = "btrfs";
      # see here: https://github.com/mamba-org/mamba/issues/2771#issuecomment-1691993724
      extraOptions = "--default-ulimit nofile=65536:65536";
    };
  };

  environment.systemPackages = [pkgs.trivy pkgs.clair];
}
