{
  disko.devices.disk.nvme0n1 = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [
              "fmask=0077"
              "dmask=0077"
            ];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "encrypted";
            extraFormatArgs = [
              "--type"
              "luks2"
            ];
            passwordFile = "/tmp/secret.key";
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              postCreateHook = ''
                MNTPOINT=$(mktemp -d)
                mount /dev/mapper/encrypted "$MNTPOINT" -o subvol=/
                trap 'umount "$MNTPOINT"; rmdir "$MNTPOINT"' EXIT
                if [ -e "$MNTPOINT/root-blank" ]; then
                  btrfs subvolume show "$MNTPOINT/root-blank" >/dev/null || {
                    echo "existing root-blank is not a btrfs subvolume" >&2
                    exit 1
                  }
                  btrfs property get -ts "$MNTPOINT/root-blank" ro | grep -Fx ro=true >/dev/null || {
                    echo "existing root-blank subvolume is not read-only" >&2
                    exit 1
                  }
                else
                  btrfs subvolume snapshot -r "$MNTPOINT/root" "$MNTPOINT/root-blank"
                fi
              '';
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "/home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "/persist" = {
                  mountpoint = "/persist";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "/swap" = {
                  mountpoint = "/.swapvol";
                  swap.swapfile.size = "8G";
                };
              };
            };
          };
        };
      };
    };
  };
}
