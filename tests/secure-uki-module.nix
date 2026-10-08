{
  pkgs,
  impermanenceModule,
  fwupdPackage,
  testSignerStub ? false,
}:
let
  inherit (pkgs) lib;
  package = pkgs.callPackage ../pkgs/secure-uki { };
  changedHelper =
    pkgs.runCommand "vm-only-changed-fwupd-helper"
      {
        nativeBuildInputs = [
          pkgs.binutils
          pkgs.python3
        ];
      }
      ''
        mkdir -p "$out/libexec/fwupd/efi"
        cp ${fwupdPackage.fwupd-efi}/libexec/fwupd/efi/fwupdx64.efi input.efi
        chmod u+w input.efi
        objcopy --dump-section .sbat=sbat input.efi
        python3 -c "from pathlib import Path; p=Path('sbat'); p.write_bytes(p.read_bytes().rstrip(b'\\0') + b'vm-only-fixture,1,VMOnly,fixture,1,https://invalid.example\\n')"
        objcopy --update-section .sbat=sbat input.efi "$out/libexec/fwupd/efi/fwupdx64.efi"
      '';
  updatedPackage = fwupdPackage.overrideAttrs (old: {
    passthru = old.passthru // {
      fwupd-efi = changedHelper;
    };
  });
  enabled = {
    virtualisation.fileSystems."/persist" = {
      device = "/dev/mapper/encrypted";
      fsType = "btrfs";
      neededForBoot = true;
    };
    boot = {
      secureUki.enable = true;
      initrd = {
        # VM ONLY: compiled synthetic key unlocks AUXILIARY state, not production root.
        # The VM module deliberately clears host LUKS settings at priority 10.
        luks.devices = lib.mkOverride 0 {
          encrypted = {
            device = "/dev/vdb";
            keyFile = "/vm-only-state.key";
          };
        };
        systemd.contents."/vm-only-state.key".source = pkgs.writeText "vm-only-state-key" "vm-state-only";
      };
    };
    services.fwupd = {
      enable = true;
      package = fwupdPackage;
    };
    systemd.services.secure-uki-fwupd-sign.serviceConfig.ExecStart = lib.mkIf testSignerStub (
      lib.mkForce "${pkgs.coreutils}/bin/true"
    );
  };
in
pkgs.testers.runNixOSTest {
  name = "dancer-secure-uki-module";
  nodes.machine = {
    imports = [
      impermanenceModule
      ../systems/profiles/boot/secure-uki
    ];
    virtualisation = {
      emptyDiskImages = [ 512 ];
      useBootLoader = true;
      useEFIBoot = true;
      useSecureBoot = true;
      efi.OVMF = (pkgs.OVMFFull.override { secureBoot = true; }).fd;
      mountHostNixStore = true;
      memorySize = 3072;
      tpm.enable = true;
    };
    boot = {
      bootspec.enable = true;
      loader = {
        systemd-boot.enable = true; # Guest-only initial stock bootstrap.
        efi.canTouchEfiVariables = true;
      };
      initrd.systemd.enable = true;
    };
    system.switch.enable = true;
    specialisation.image-a.configuration = enabled // {
      boot = lib.recursiveUpdate enabled.boot { secureUki.bootstrapLabel = "dancer-uki-bootstrap"; };
    };
    specialisation.image-b.configuration = _: {
      config = lib.mkMerge [
        enabled
        {
          boot.secureUki.bootstrapLabel = "dancer-uki-ready";
          services.fwupd.package = lib.mkForce updatedPackage;
        }
      ];
    };
    environment.systemPackages = [
      pkgs.python3
      pkgs.openssl
      pkgs.sbctl
      pkgs.cryptsetup
      pkgs.util-linux
      pkgs.btrfs-progs
      pkgs.sbsigntool
    ];
  };
  testScript =
    { nodes, ... }:
    let
      a = nodes.machine.specialisation.image-a.configuration.system.build.toplevel;
      b = nodes.machine.specialisation.image-b.configuration.system.build.toplevel;
      configA = nodes.machine.specialisation.image-a.configuration;
      installA = configA.system.build.installBootLoader;
      installB = nodes.machine.specialisation.image-b.configuration.system.build.installBootLoader;
    in
    ''
      SECURE_UKI_PYTHONPATH = "${package}/${pkgs.python3.sitePackages}"
      ${builtins.readFile ./secure-uki-vm-helpers.py}
      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.succeed("printf vm-state-only | cryptsetup luksFormat --type luks2 --batch-mode --key-file=- /dev/vdb")
      machine.succeed("printf vm-state-only | cryptsetup open --key-file=- /dev/vdb encrypted")
      machine.succeed("mkfs.btrfs /dev/mapper/encrypted; mkdir -p /persist; mount /dev/mapper/encrypted /persist")
      machine.succeed("mkdir -p /persist/var/lib/sbctl /persist/var/lib/secure-uki /var/lib/sbctl /var/lib/secure-uki; chmod 700 /persist/var/lib/{sbctl,secure-uki}; mount --bind /persist/var/lib/sbctl /var/lib/sbctl; mount --bind /persist/var/lib/secure-uki /var/lib/secure-uki")
      machine.succeed("sbctl create-keys")
      make_test_keys(machine, "/var/lib/secure-uki/pcr-signing")
      # Use the module's actual protected config and external install hook; never
      # assemble a second production signer or run host physical activation.
      machine.succeed("ln -sfn ${configA.environment.etc."secure-uki.json".source} /etc/secure-uki.json")
      machine.succeed("${installA} ${a}")
      machine.succeed("rm -f /boot/loader/entries/*.conf")
      machine.succeed("sbctl enroll-keys --yes-this-might-brick-my-machine")
      cold_restart(machine)
      machine.wait_for_unit("multi-user.target")
      machine.succeed("test $(readlink -f /run/booted-system) = ${a}")
      machine.wait_until_succeeds("test $(systemctl show secure-uki-confirm -p ActiveState --value) = active")
      machine.wait_until_succeeds("python3 -c 'import json; m=json.load(open(\"/var/lib/secure-uki/manifest.json\")); assert m[\"known_good\"] == m[\"default\"]'")
      machine.succeed("bootctl status | grep -E 'Secure Boot: enabled'")

      cert = "/var/lib/sbctl/keys/db/db.pem"
      signed = "/run/fwupd-efi/fwupdx64.efi.signed"
      def verify_helper(source):
          assert machine.execute("sbverify --cert " + cert + " " + signed)[0] == 0, "unsigned/mismatched runtime helper accepted"
          machine.succeed("cmp /run/fwupd-efi/fwupdx64.efi " + source)
          machine.succeed("systemctl is-active fwupd")

      source_a = "${fwupdPackage.fwupd-efi}/libexec/fwupd/efi/fwupdx64.efi"
      source_b = "${changedHelper}/libexec/fwupd/efi/fwupdx64.efi"
      machine.succeed("printf stale-unsigned-marker > " + signed)
      machine.succeed("systemctl start fwupd")
      verify_helper(source_a)
      for operation in ("daemon restart", "tmpfiles reapply"):
          machine.succeed("printf stale-unsigned-marker > " + signed)
          if operation == "tmpfiles reapply":
              machine.succeed("systemd-tmpfiles --create")
          machine.succeed("systemctl restart fwupd")
          verify_helper(source_a)
      machine.succeed("systemctl stop fwupd; mv /var/lib/sbctl/keys/db/db.key /var/lib/sbctl/keys/db/db.key.hold")
      machine.succeed("printf stale-marker > " + signed)
      machine.fail("systemctl start fwupd")
      machine.succeed("test ! -e " + signed)
      machine.fail("systemctl is-active fwupd")
      machine.succeed("mv /var/lib/sbctl/keys/db/db.key.hold /var/lib/sbctl/keys/db/db.key; systemctl reset-failed; systemctl start fwupd")
      verify_helper(source_a)

      # Missing keys refused above; mismatched certificate also cannot leave a
      # signed marker or allow the daemon. Guest-only temporary alternate cert.
      machine.succeed("systemctl stop fwupd; cp " + cert + " " + cert + ".hold")
      machine.succeed("openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=vm-wrong-db -keyout /run/wrong.key -out " + cert)
      machine.fail("systemctl start fwupd")
      machine.succeed("test ! -e " + signed)
      machine.fail("systemctl is-active fwupd")
      machine.succeed("mv " + cert + ".hold " + cert + "; rm /run/wrong.key; systemctl reset-failed; systemctl start fwupd")
      verify_helper(source_a)
      machine.succeed("${installB} ${b}")
      cold_restart(machine)
      machine.wait_for_unit("multi-user.target")
      machine.succeed("test $(readlink -f /run/booted-system) = ${b}")
      machine.wait_until_succeeds("test $(systemctl show secure-uki-confirm -p ActiveState --value) = active")
      machine.succeed("systemctl start fwupd")
      verify_helper(source_b)
      machine.fail("cmp /run/fwupd-efi/fwupdx64.efi " + source_a)
      cold_restart(machine)
      machine.wait_for_unit("multi-user.target")
      machine.succeed("test ! -e " + signed)
      machine.succeed("systemctl start fwupd")
      verify_helper(source_b)
      print("Real opt-in module, native hook, confirmation and runtime fwupd signing passed")
    '';
}
