{ pkgs }:
let
  inherit (pkgs) lib;
  package = pkgs.callPackage ../pkgs/secure-uki { };
  ukify = pkgs.writeShellScriptBin "ukify" ''
    exec ${pkgs.systemdUkify}/lib/systemd/ukify --stub=${pkgs.systemd}/lib/systemd/boot/efi/linuxx64.efi.stub "$@"
  '';
  runtime = {
    version = 1;
    esp = "/boot";
    state_dir = "/var/lib/secure-uki";
    encrypted_device = "/dev/mapper/encrypted";
    state_filesystem = "ext4"; # Disposable state disk; production Btrfs is Task 6.
    tools = {
      ukify = "${ukify}/bin/ukify";
      measure = "${pkgs.systemd}/lib/systemd/systemd-measure";
      sbsign = "${pkgs.sbsigntool}/bin/sbsign";
      sbverify = "${pkgs.sbsigntool}/bin/sbverify";
      bootctl = "${pkgs.systemd}/bin/bootctl";
      nix_store = "${pkgs.nix}/bin/nix-store";
      systemctl = "${pkgs.systemd}/bin/systemctl";
      findmnt = "${pkgs.util-linux}/bin/findmnt";
      cryptsetup = "${pkgs.cryptsetup}/bin/cryptsetup";
    };
    keys = {
      db_key = "/var/lib/sbctl/keys/db/db.key";
      db_cert = "/var/lib/sbctl/keys/db/db.pem";
      pcr_private = "/var/lib/secure-uki/pcr-signing/private.pem";
      pcr_public = "/var/lib/secure-uki/pcr-signing/public.pem";
    };
  };
in
pkgs.testers.runNixOSTest {
  name = "dancer-secure-uki-publication";
  nodes.machine = {
    virtualisation = {
      emptyDiskImages = [ 512 ];
      useBootLoader = true;
      useEFIBoot = true;
      useSecureBoot = true;
      efi.OVMF = (pkgs.OVMFFull.override { secureBoot = true; }).fd;
      mountHostNixStore = true;
      memorySize = 3072;
    };
    boot.bootspec.enable = true;
    boot.loader.systemd-boot.enable = true; # Test bootstrap only, not integration module.
    boot.loader.efi.canTouchEfiVariables = true;
    boot.initrd.systemd.enable = true;
    system.switch.enable = true;
    specialisation.image-a.configuration = { };
    specialisation.image-b.configuration.boot.kernelParams = [ "publication_fixture=updated" ];
    environment.etc."secure-uki.json".text = builtins.toJSON runtime;
    environment.systemPackages = [
      package
      pkgs.python3
      pkgs.openssl
      pkgs.sbctl
      pkgs.cryptsetup
      pkgs.util-linux
      pkgs.e2fsprogs
    ];
    # VM ONLY: synthetic passphrase unlocks an auxiliary state disk, not the OS
    # root. This tests CLI mount ordering, not unattended encrypted-root boot.
    systemd.services.fixture-state = {
      wantedBy = [ "multi-user.target" ];
      before = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      path = [
        pkgs.cryptsetup
        pkgs.util-linux
        pkgs.e2fsprogs
        pkgs.coreutils
      ];
      script = ''
        if ! blkid /dev/vdb; then
          printf vm-state-only | cryptsetup luksFormat --type luks2 --batch-mode --key-file=- /dev/vdb
          printf vm-state-only | cryptsetup open --key-file=- /dev/vdb encrypted
          mkfs.ext4 /dev/mapper/encrypted
        else
          printf vm-state-only | cryptsetup open --key-file=- /dev/vdb encrypted
        fi
        mkdir -p /mnt/fixture-state /var/lib/secure-uki /var/lib/sbctl
        mount /dev/mapper/encrypted /mnt/fixture-state
        mkdir -p /mnt/fixture-state/state /mnt/fixture-state/sbctl
        chmod 0700 /mnt/fixture-state/state /mnt/fixture-state/sbctl
        mount --bind /mnt/fixture-state/state /var/lib/secure-uki
        mount --bind /mnt/fixture-state/sbctl /var/lib/sbctl
      '';
    };
  };
  testScript =
    { nodes, ... }:
    let
      a = nodes.machine.specialisation.image-a.configuration.system.build.toplevel;
      b = nodes.machine.specialisation.image-b.configuration.system.build.toplevel;
    in
    ''
      SECURE_UKI_PYTHONPATH = "${package}/${pkgs.python3.sitePackages}"
      ${builtins.readFile ./secure-uki-vm-helpers.py}
      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("fixture-state.service")
      machine.succeed("sbctl create-keys")
      make_test_keys(machine, "/var/lib/secure-uki/pcr-signing")
      machine.succeed("secure-uki install ${a}")
      # Remove legacy bootstrap menus, so fallback cannot masquerade as UKI boot.
      machine.succeed("rm -f /boot/loader/entries/*.conf")
      # Enroll keys only in disposable OVMF, never on physical firmware.
      machine.succeed("sbctl enroll-keys --yes-this-might-brick-my-machine")
      cold_restart(machine)
      machine.succeed("test $(readlink -f /run/booted-system) = ${a}")
      machine.wait_until_succeeds("systemctl is-system-running")
      machine.succeed("secure-uki confirm-boot")
      manifest = json.loads(machine.succeed("cat /var/lib/secure-uki/manifest.json"))
      confirmed_a = manifest["known_good"]
      assert confirmed_a == manifest["default"]
      assert machine.succeed("bootctl --print-stub-path").strip() == "/boot/EFI/Linux/" + confirmed_a
      machine.succeed("bootctl status | grep -E 'Secure Boot: enabled'")

      # Instrument the real guest CLI, never production code. SIGKILL is sent
      # only to this installer process after a real durable publication action.
      kill_script = ${builtins.toJSON (builtins.readFile ./secure-uki-publish-kill.py)}
      machine.succeed("cat > /var/lib/secure-uki/fixture-kill.py <<'PY'\n" + kill_script + "\nPY")
      for boundary in ("image", "primary", "selection", "manifest"):
          with subtest("guest installer kill after " + boundary):
              status, output = machine.execute("env PYTHONPATH=" + SECURE_UKI_PYTHONPATH +
                                               " python3 /var/lib/secure-uki/fixture-kill.py " + boundary + " install ${b}")
              assert status == 137 and "KILL_BOUNDARY=" + boundary in output
              cold_restart(machine)
              machine.wait_until_succeeds("systemctl is-system-running")
              assert machine.succeed("readlink -f /run/booted-system").strip() in ("${a}", "${b}")
              state = json.loads(machine.succeed("cat /var/lib/secure-uki/manifest.json"))
              assert state["known_good"] == confirmed_a
              machine.succeed("test -f /boot/EFI/Linux/" + confirmed_a)
              machine.succeed("test -L /var/lib/secure-uki/gc-roots/" + confirmed_a)
              machine.succeed("secure-uki install ${b}")
              state = json.loads(machine.succeed("cat /var/lib/secure-uki/manifest.json"))
              assert state["known_good"] == confirmed_a
              assert len(state["images"]) == 2
              assert int(machine.succeed("find /boot/EFI/Linux -name 'dancer-*.efi' -printf '1\\n' | wc -l")) == 2
              machine.succeed("test ! -e /var/lib/secure-uki/journal.json")
              assert int(machine.succeed("find /boot/EFI/secure-uki -name 'systemd-boot-*.efi' -printf '1\\n' | wc -l")) <= 2

      cold_restart(machine)
      machine.succeed("test $(readlink -f /run/booted-system) = ${b}")
      machine.wait_until_succeeds("systemctl is-system-running")
      machine.succeed("secure-uki confirm-boot")
      state = json.loads(machine.succeed("cat /var/lib/secure-uki/manifest.json"))
      assert state["known_good"] == state["default"]
      # Normal installer replay of the previous closure, not stock activation.
      machine.succeed("secure-uki install ${a}")
      cold_restart(machine)
      machine.succeed("test $(readlink -f /run/booted-system) = ${a}")
      machine.wait_until_succeeds("systemctl is-system-running")
      machine.succeed("secure-uki confirm-boot")
      print("Actual signed publication/confirmation and guest process-kill recovery passed")
    '';
}
