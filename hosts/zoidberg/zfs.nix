{
  config,
  pkgs,
  ...
}: {
  boot = {
    supportedFilesystems = ["zfs"];

    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

    loader = {
      efi = {
        efiSysMountPoint = "/boot/efi";
        canTouchEfiVariables = false;
      };
      generationsDir.copyKernels = true;
      grub = {
        efiInstallAsRemovable = true;
        enable = true;
        version = 2;
        copyKernels = true;
        efiSupport = true;
        zfsSupport = true;
        extraPrepareConfig = ''
          mkdir -p /boot/efis
          for i in  /boot/efis/*; do mount $i ; done

          mkdir -p /boot/efi
          mount /boot/efi
        '';
        extraInstallCommands = ''
          ESP_MIRROR=$(mktemp -d)
          cp -r /boot/efi/EFI $ESP_MIRROR
          for i in /boot/efis/*; do cp -r $ESP_MIRROR/EFI $i ; done
          rm -rf $ESP_MIRROR
        '';
        devices = [
          "/dev/disk/by-id/nvme-SAMSUNG_MZVLB512HAJQ-000L7_S3TNNE0JB06744"
        ];
      };
    };
  };

  # ZFS maintenance settings.
  services.zfs = {
    trim.enable = true;
    autoScrub.enable = true;
  };
}
