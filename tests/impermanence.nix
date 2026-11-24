{
  pkgs,
  disko,
  impermanence,
  disableRollback ? false,
}:
let
  inherit (pkgs) lib;
  testPackage = pkgs.writeTextFile {
    name = "task7-nix-metadata-package";
    text = "task7 nix metadata marker\n";
    destination = "/share/task7-nix-metadata/marker";
  };
  testPackageClosureInfo = pkgs.closureInfo {
    rootPaths = [ testPackage ];
  };
  diskoLib = pkgs.callPackage (disko.outPath + "/lib") {
    eval-config = import (pkgs.path + "/nixos/lib/eval-config.nix");
    makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
    qemu-common = import (pkgs.path + "/nixos/lib/qemu-common.nix");
  };
  layout = lib.recursiveUpdate (import ../systems/x86_64-linux/dancer/disk-config.nix) {
    disko.devices.disk.nvme0n1.content.partitions = {
      ESP.size = "512M";
      luks.content.content.subvolumes."/swap".swap.swapfile.size = "256M";
    };
  };
in

diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "dancer-impermanence";
  disko-config = layout;
  postDisko = ''
    machine.succeed("mkdir -p /mnt/nix/store /mnt/nix/var/nix/db /mnt/nix/var/nix/profiles")
    machine.succeed("findmnt -T /mnt/nix/store -n -o TARGET,SOURCE,FSTYPE,OPTIONS | grep -F btrfs | grep -F /dev/mapper/encrypted")
    machine.succeed("findmnt -T /mnt/nix/var/nix -n -o TARGET,SOURCE,FSTYPE,OPTIONS | grep -F btrfs | grep -F /dev/mapper/encrypted")
    machine.succeed("nix-store --store /mnt --load-db < ${testPackageClosureInfo}/registration")
  '';
  extraSystemConfig = {
    imports = [
      impermanence.nixosModules.impermanence
      ../systems/profiles/impermanence
      ../systems/profiles/services/tailscale/dancer-ssh.nix
    ];

    boot.initrd = {
      systemd = {
        enable = true;
        services = {
          root-roolback.requiredBy = lib.mkIf disableRollback (lib.mkForce [ ]);
          # The final boot deliberately enters initrd emergency mode. Let the
          # probe inspect it instead of letting test-instrumentation panic.
          panic-on-fail.wantedBy = lib.mkIf (!disableRollback) (lib.mkForce [ ]);
          verify-failed-rollback = lib.mkIf (!disableRollback) {
            wantedBy = [ "emergency.target" ];
            unitConfig.DefaultDependencies = false;
            serviceConfig.Type = "oneshot";
            script = ''
              systemctl is-failed --quiet root-roolback.service
              command -v findmnt >/dev/null
              if findmnt -M /sysroot; then exit 1; fi
              mount -t btrfs -o ro,subvolid=5 /dev/mapper/encrypted /mnt
              trap 'umount /mnt' EXIT
              test -f '/mnt/root/nested parent/nested child/keep-on-failure'
              echo "rollback failure preserved root and blocked sysroot" >/dev/ttyS0
            '';
          };
        };
      };
      luks.devices.encrypted.keyFile = "/tmp/secret.key";
    };
    # Test the production state bind mount with a synthetic marker only. No
    # daemon, real node identity, credentials, or enrollment in this VM.
    services.tailscale.enable = lib.mkForce false;
    fileSystems."/persist".neededForBoot = true;
    environment.systemPackages = [
      pkgs.sqlite
    ];
  };
  extraTestScript = ''
    machine.succeed("cryptsetup luksDump /dev/vda2 | grep -E 'Version:[[:space:]]+2'")
    machine.succeed("findmnt -n -o FSTYPE / | grep -Fx btrfs")
    machine.succeed("mkdir -p /mnt/btrfs-root && mount -o subvol=/ /dev/mapper/encrypted /mnt/btrfs-root")
    machine.succeed("test -d /mnt/btrfs-root/root-blank")
    machine.succeed("btrfs property get -ts /mnt/btrfs-root/root-blank ro | grep -Fx 'ro=true'")
    machine.succeed("umount /mnt/btrfs-root && rmdir /mnt/btrfs-root")
    ${lib.optionalString (!disableRollback) ''
      machine.succeed("journalctl -b -o cat -u root-roolback.service | grep -F 'Rollback BTRFS root subvolume to a pristine state'")
      machine.succeed("journalctl -b -o cat -u root-roolback.service | grep -F 'restoring blank /root subvolume'")
    ''}
    machine.succeed("test -e /.swapvol/swapfile")
    machine.succeed("swapon --show=NAME --noheadings | grep -Fx /.swapvol/swapfile")
    log.info("TASK8: pre-reset mount /boot: " + machine.succeed("findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /boot"))
    machine.succeed("findmnt -n -o FSTYPE /boot | grep -Fx vfat")
    machine.succeed("findmnt -n -o OPTIONS /boot | grep -F fmask=0077 | grep -F dmask=0077")
    machine.succeed("umask 077; printf task8-vm-efi-seed > /boot/task8-efi-seed")
    machine.succeed("test \"$(stat -c %u /boot/task8-efi-seed)\" = 0")
    machine.succeed("stat -c %a /boot/task8-efi-seed | grep -E '^[0-7]00$'")
    machine.succeed("findmnt -n -o SOURCE /var/lib/tailscale | grep -F /persist/var/lib/tailscale")
    machine.succeed("test \"$(stat -c %u:%g:%a /var/lib/tailscale)\" = 0:0:700")
    machine.succeed("test \"$(stat -c %u:%g:%a /persist/var/lib/tailscale)\" = 0:0:700")
    machine.succeed("umask 077; printf synthetic-not-node-state > /var/lib/tailscale/persistence-marker")
    machine.succeed("touch /root-reset-probe /home/home-probe /persist/persist-probe /nix/nix-probe /var/lib/nixos/nixos-probe")
    machine.succeed("mkdir -p /etc/NetworkManager/system-connections")
    machine.succeed("install -m 0600 /dev/stdin /etc/NetworkManager/system-connections/synthetic.nmconnection <<'EOF'\n[connection]\nid=synthetic\ntype=ethernet\ninterface-name=eth-test\n\n[ipv4]\nmethod=disabled\n\n[ipv6]\nmethod=ignore\nEOF")
    machine.succeed("test -e /etc/ssh/ssh_host_ed25519_key || ssh-keygen -q -t ed25519 -N \"\" -f /etc/ssh/ssh_host_ed25519_key")
    key_before = machine.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub")
    machine_id_before = machine.succeed("cat /etc/machine-id")
    nm_before = machine.succeed("cat /etc/NetworkManager/system-connections/synthetic.nmconnection")
    log.info("TASK7: pre-reset mount /: " + machine.succeed("findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /"))
    log.info("TASK7: pre-reset mount /home: " + machine.succeed("findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /home"))
    log.info("TASK7: pre-reset mount /nix: " + machine.succeed("findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /nix"))
    log.info("TASK7: pre-reset mount /persist: " + machine.succeed("findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /persist"))
    log.info("TASK7: pre-reset mount /var/lib/nixos: " + machine.succeed("findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /var/lib/nixos"))
    machine.succeed("findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /var/lib/nixos | grep -F /persist/var/lib/nixos")
    machine.succeed("test ! -e /nix/var/nix/profiles/task7-package-profile")
    machine.succeed("ln -sfn ${testPackage} /nix/var/nix/profiles/task7-package-profile")
    machine.succeed("test \"$(readlink -f /nix/var/nix/profiles/task7-package-profile)\" = \"${testPackage}\"")
    machine.succeed("test -e ${testPackage}/share/task7-nix-metadata/marker")
    log.info("TASK7: pre-reset mount /nix/var/nix/profiles: " + machine.succeed("findmnt -T /nix/var/nix/profiles -n -o TARGET,SOURCE,FSTYPE,OPTIONS"))
    log.info("TASK7: pre-reset mount /nix/var/nix/db: " + machine.succeed("findmnt -T /nix/var/nix/db -n -o TARGET,SOURCE,FSTYPE,OPTIONS"))
    machine.succeed("findmnt -T /nix/var/nix/profiles -n -o TARGET,SOURCE,FSTYPE,OPTIONS | grep -F '/nix /dev/mapper/encrypted' | grep -F btrfs")
    machine.succeed("findmnt -T /nix/var/nix/db -n -o TARGET,SOURCE,FSTYPE,OPTIONS | grep -F '/nix /dev/mapper/encrypted' | grep -F btrfs")
    machine.succeed("test -s /nix/var/nix/db/db.sqlite")
    package_metadata_before = machine.succeed("sqlite3 -readonly -cmd '.timeout 5000' /nix/var/nix/db/db.sqlite \"select path || ' ' || hash || ' ' || narSize from ValidPaths where path='${testPackage}';\"")
    assert len(package_metadata_before.strip().splitlines()) == 1, package_metadata_before
    log.info("TASK7: pre-reset package metadata: " + package_metadata_before)
    machine.succeed("test -e /root-reset-probe")
    machine.succeed("test -e /home/home-probe")
    machine.succeed("test -e /persist/persist-probe")
    machine.succeed("test -e /nix/nix-probe")
    machine.succeed("test -e /var/lib/nixos/nixos-probe")
    machine.succeed("btrfs subvolume create '/nested parent' && btrfs subvolume create '/nested parent/nested child'")
    machine.succeed("sync")
    log.info("TASK7: resetting VM for reset/persistence assertions")
    machine.send_monitor_command("system_reset")
    machine.wait_for_shutdown()
    machine.start()
    machine.wait_for_unit("multi-user.target", timeout=120)
    log.info("TASK7: reset VM reached multi-user.target")
    ${lib.optionalString (!disableRollback) ''
      machine.succeed("journalctl -b -o cat -u root-roolback.service | grep -F 'Rollback BTRFS root subvolume to a pristine state'")
      machine.succeed("journalctl -b -o cat -u root-roolback.service | grep -F 'restoring blank /root subvolume'")
    ''}
    log.info("TASK7: post-reset mount /: " + machine.succeed("findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /"))
    log.info("TASK7: post-reset mount /home: " + machine.succeed("findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /home"))
    log.info("TASK7: post-reset mount /nix: " + machine.succeed("findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /nix"))
    log.info("TASK7: post-reset mount /persist: " + machine.succeed("findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /persist"))
    log.info("TASK7: post-reset mount /var/lib/nixos: " + machine.succeed("findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /var/lib/nixos"))
    log.info("TASK7: post-reset path status: " + machine.succeed("for p in /root-reset-probe /home/home-probe /persist/persist-probe /nix/nix-probe /var/lib/nixos/nixos-probe /nix/var/nix/profiles/task7-package-profile; do if test -e \"$p\"; then echo \"$p present\"; else echo \"$p missing\"; fi; done"))
    machine.succeed("findmnt -n -o SOURCE /var/lib/tailscale | grep -F /persist/var/lib/tailscale")
    machine.succeed("test \"$(stat -c %u:%g:%a /var/lib/tailscale)\" = 0:0:700")
    machine.succeed("test \"$(stat -c %u:%g:%a /persist/var/lib/tailscale)\" = 0:0:700")
    machine.succeed("grep -Fx synthetic-not-node-state /var/lib/tailscale/persistence-marker")
    machine.succeed("test \"$(stat -c %u:%g:%a /var/lib/tailscale/persistence-marker)\" = 0:0:600")
    machine.fail("test -e '/nested parent'")
    machine.fail("test -e /root-reset-probe")
    machine.succeed("test -e /home/home-probe")
    machine.succeed("test -e /persist/persist-probe")
    machine.succeed("test -e /nix/nix-probe")
    machine.succeed("test -e /var/lib/nixos/nixos-probe")
    machine.succeed("test \"$(readlink -f /nix/var/nix/profiles/task7-package-profile)\" = \"${testPackage}\"")
    machine.succeed("test -e ${testPackage}/share/task7-nix-metadata/marker")
    log.info("TASK7: post-reset mount /nix/var/nix/profiles: " + machine.succeed("findmnt -T /nix/var/nix/profiles -n -o TARGET,SOURCE,FSTYPE,OPTIONS"))
    log.info("TASK7: post-reset mount /nix/var/nix/db: " + machine.succeed("findmnt -T /nix/var/nix/db -n -o TARGET,SOURCE,FSTYPE,OPTIONS"))
    machine.succeed("findmnt -T /nix/var/nix/profiles -n -o TARGET,SOURCE,FSTYPE,OPTIONS | grep -F '/nix /dev/mapper/encrypted' | grep -F btrfs")
    machine.succeed("findmnt -T /nix/var/nix/db -n -o TARGET,SOURCE,FSTYPE,OPTIONS | grep -F '/nix /dev/mapper/encrypted' | grep -F btrfs")
    package_metadata_after = machine.succeed("sqlite3 -readonly -cmd '.timeout 5000' /nix/var/nix/db/db.sqlite \"select path || ' ' || hash || ' ' || narSize from ValidPaths where path='${testPackage}';\"")
    assert len(package_metadata_after.strip().splitlines()) == 1, package_metadata_after
    assert package_metadata_after == package_metadata_before
    log.info("TASK7: post-reset package metadata: " + package_metadata_after)
    assert machine.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub") == key_before
    assert machine.succeed("cat /etc/machine-id") == machine_id_before
    assert machine.succeed("cat /etc/NetworkManager/system-connections/synthetic.nmconnection") == nm_before
    machine.succeed("stat -c %a /etc/NetworkManager/system-connections/synthetic.nmconnection | grep -Fx 600")
    log.info("TASK8: post-reset mount /boot: " + machine.succeed("findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /boot"))
    machine.succeed("findmnt -n -o OPTIONS /boot | grep -F fmask=0077 | grep -F dmask=0077")
    machine.succeed("test \"$(stat -c %u /boot/task8-efi-seed)\" = 0")
    machine.succeed("stat -c %a /boot/task8-efi-seed | grep -E '^[0-7]00$'")
    machine.succeed("test -e /.swapvol/swapfile")
    machine.succeed("swapon --show=NAME --noheadings | grep -Fx /.swapvol/swapfile")
    ${lib.optionalString (!disableRollback) ''
      with subtest("writable blank blocks boot before deleting any subvolumes"):
          machine.succeed("btrfs subvolume create '/nested parent' && btrfs subvolume create '/nested parent/nested child' && touch '/nested parent/nested child/keep-on-failure'")
          machine.succeed("mkdir -p /mnt/btrfs-root && mount -o subvolid=5 /dev/mapper/encrypted /mnt/btrfs-root")
          machine.succeed("btrfs property set -ts /mnt/btrfs-root/root-blank ro false && umount /mnt/btrfs-root && sync")
          machine.send_monitor_command("system_reset")
          machine.wait_for_shutdown()
          machine.start()
          # The pinned wait_for_console_text drains only one queued line per
          # retry. Inspect the accumulated log so boot chatter cannot hide a pass.
          import time
          deadline = time.monotonic() + 120
          while "rollback failure preserved root and blocked sysroot" not in machine.get_console_log():
              assert time.monotonic() < deadline, "initrd did not confirm safe rollback failure"
              time.sleep(0.25)
    ''}
  '';
}
