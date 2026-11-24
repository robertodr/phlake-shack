{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Referencing an executable in a service script does not install it into stage 1.
  boot.initrd.systemd.extraBin.findmnt = "${pkgs.util-linux}/bin/findmnt";
  boot.initrd.systemd.services.root-roolback = {
    description = "Rollback BTRFS root subvolume to a pristine state";
    requiredBy = [ "sysroot.mount" ];
    after = [
      # LUKS/TPM process
      "systemd-cryptsetup@encrypted.service"
      # Now that suspend-then-hibernate is in use, the rollback must not
      # get a chance to run on a resume boot: the resumed image's page
      # cache still refers to the /root subvolume this service deletes.
      # There is no explicit ordering otherwise, so it is a race. Placing
      # the rollback after the resume attempt settles it, because a
      # successful resume never returns to the initrd, while an ordinary
      # boot has systemd-hibernate-resume exit immediately.
      "systemd-hibernate-resume.service"
    ];
    before = [
      "sysroot.mount"
    ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig = {
      Type = "oneshot";
      # Stage 1 requests initrd-fs.target again after parsing /sysroot/etc/fstab.
      # Satisfy subsequent mount dependencies without repeating the rollback.
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      die() { echo "root rollback: $*" >&2; exit 1; }

      if findmnt -n -M /sysroot >/dev/null; then die "/sysroot already mounted"; fi
      mkdir -p /mnt
      mount -t btrfs -o subvolid=5 /dev/mapper/encrypted /mnt
      trap 'umount /mnt' EXIT
      # Match the mountpoint itself (not a containing filesystem), its
      # backing device, filesystem type and top-level filesystem root.
      test "$(findmnt -n -o FSROOT -M /mnt -S /dev/mapper/encrypted -t btrfs)" = / ||
        die "unexpected rollback mount"
      for subvol in /mnt/root-blank /mnt/root; do
        test ! -L "$subvol" && btrfs subvolume show "$subvol" >/dev/null ||
          die "$subvol is not a subvolume"
      done
      test "$(btrfs property get -ts /mnt/root-blank ro)" = ro=true ||
        die "root-blank is not read-only"

      # Let btrfs traverse child subvolumes without parsing pathnames.
      btrfs subvolume delete --recursive /mnt/root
      echo "restoring blank /root subvolume..."
      btrfs subvolume snapshot /mnt/root-blank /mnt/root
      umount /mnt
      trap - EXIT
    '';
  };

  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = lib.mkMerge [
    {
      hideMounts = true;
      directories = lib.mkBefore [
        "/etc/NetworkManager/system-connections"
      ];
      files = [
        "/etc/machine-id"
        {
          file = "/var/keys/secret_file";
          parentDirectory = {
            mode = "u=rwx,g=,o=";
          };
        }
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    }
    (lib.mkIf config.virtualisation.docker.enable {
      directories = [
        "/var/lib/docker"
      ];
    })
    {
      directories = lib.mkAfter [
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/var/lib/systemd/timers"
        "/var/log"
      ];
    }
  ];
}
