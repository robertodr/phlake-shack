{ pkgs }:
let
  inherit (pkgs) lib;
  ukify = pkgs.writeShellScriptBin "ukify" ''
    exec ${pkgs.systemdUkify}/lib/systemd/ukify "$@"
  '';
in
pkgs.testers.runNixOSTest {
  name = "dancer-secure-uki-probe";
  nodes.machine = {
    virtualisation = {
      emptyDiskImages = [ 512 ];
      useBootLoader = true;
      useEFIBoot = true;
      useSecureBoot = true;
      efi.OVMF = (pkgs.OVMFFull.override { secureBoot = true; }).fd;
      tpm.enable = true;
      mountHostNixStore = true;
      memorySize = 3072;
    };
    boot = {
      bootspec.enable = true;
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      initrd.systemd = {
        enable = true;
        tpm2 = {
          enable = true;
          pcrphases.enable = true;
        };
      };
    };
    systemd.tpm2.pcrphases.enable = true;
    system.switch.enable = true;
    environment.systemPackages = [
      ukify
      pkgs.sbctl
      pkgs.openssl
      pkgs.sbsigntool
      pkgs.cryptsetup
      pkgs.python3
      pkgs.tpm2-tools
    ];
    specialisation.boot-luks.configuration = {
      boot.initrd.luks.devices = lib.mkVMOverride {
        cryptroot = {
          device = "/dev/vdb";
          crypttabExtraOpts = [ "tpm2-device=auto" ];
        };
      };
      virtualisation.rootDevice = "/dev/mapper/cryptroot";
    };
    specialisation.boot-luks-updated.configuration = {
      boot.initrd.luks.devices = lib.mkVMOverride {
        cryptroot = {
          device = "/dev/vdb";
          crypttabExtraOpts = [ "tpm2-device=auto" ];
        };
      };
      boot.initrd.systemd.contents."/etc/probe-updated-initrd".source = pkgs.writeText "probe-updated-initrd" "updated\n";
      virtualisation.rootDevice = "/dev/mapper/cryptroot";
    };
  };
  # Separate negative-control guest: firmware refusal leaves no running OS.
  nodes.unsigned = {
    virtualisation = {
      useBootLoader = true;
      useEFIBoot = true;
      useSecureBoot = true;
      efi.OVMF = (pkgs.OVMFFull.override { secureBoot = true; }).fd;
      memorySize = 1536;
    };
    boot = {
      bootspec.enable = true;
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      initrd.systemd.enable = true;
    };
    environment.systemPackages = [
      ukify
      pkgs.sbctl
      pkgs.openssl
      pkgs.sbsigntool
      pkgs.python3
    ];
  };
  testScript =
    { nodes, ... }:
    let
      base = nodes.machine.system.build.toplevel;
      unsignedBase = nodes.unsigned.system.build.toplevel;
      luks = nodes.machine.specialisation.boot-luks.configuration.system.build.toplevel;
      updated = nodes.machine.specialisation.boot-luks-updated.configuration.system.build.toplevel;
    in
    ''
      ${builtins.readFile ./secure-uki-vm-helpers.py}

      machine.start(allow_reboot=True)
      machine.wait_for_unit("multi-user.target")
      machine.succeed("sbctl create-keys")
      make_test_keys(machine, "/var/lib/test-pcr")
      machine.succeed("install -d -m 0700 /var/lib/probe-images; mkdir -p /boot/EFI/Linux")
      build_guest_uki(machine, "${base}", "/var/lib/test-pcr",
                      "/var/lib/probe-images/probe-base.efi")
      # Verify final UEFI signing before any boot publication.
      machine.succeed("sbverify --cert /var/lib/sbctl/keys/db/db.pem "
                      "/var/lib/probe-images/probe-base.efi")
      machine.succeed("sbctl sign /boot/EFI/systemd/systemd-bootx64.efi")
      machine.succeed("sbctl sign /boot/EFI/BOOT/BOOTX64.EFI")
      machine.succeed("cp /var/lib/probe-images/probe-base.efi /boot/EFI/Linux/probe-base.efi")
      select_probe_image(machine, "probe-base.efi")
      # Safe only in this disposable OVMF guest, never a physical enrollment recipe.
      machine.succeed("sbctl enroll-keys --yes-this-might-brick-my-machine")
      cold_restart(machine)
      verify_uki_boot(machine, "base", "${base}")

      # VM fixture only: prepare a fresh disposable disk with independent recovery.
      build_guest_uki(machine, "${luks}", "/var/lib/test-pcr",
                      "/var/lib/probe-images/probe-luks.efi", marker="luks")
      build_guest_uki(machine, "${updated}", "/var/lib/test-pcr",
                      "/var/lib/probe-images/probe-updated.efi", marker="updated")
      machine.succeed("printf vm-recovery-only | cryptsetup luksFormat --type luks2 "
                      "--batch-mode --iter-time=1 /dev/vdb -")
      machine.succeed("printf vm-recovery-only | cryptsetup open --key-file=- /dev/vdb cryptroot")
      machine.succeed("mkfs.ext4 /dev/mapper/cryptroot; mkdir -p /mnt/probe-root; "
                      "mount /dev/mapper/cryptroot /mnt/probe-root")
      machine.succeed("mkdir -p /mnt/probe-root/var/lib; "
                      "cp -a /var/lib/sbctl /var/lib/test-pcr /var/lib/probe-images /mnt/probe-root/var/lib/; "
                      "printf encrypted-vm-marker > /mnt/probe-root/probe-root-marker; "
                      "umount /mnt/probe-root; cryptsetup close cryptroot")
      pcr12_normal = machine.succeed("tpm2_pcrread sha256:12")
      log.info("VM normal SHA256 PCR12:\n" + pcr12_normal)
      enroll = ("PASSWORD=vm-recovery-only systemd-cryptenroll /dev/vdb "
                "--tpm2-device=auto --tpm2-with-pin=no --tpm2-pcrlock= "
                "--tpm2-pcrs=7:sha256+12:sha256 --tpm2-public-key-pcrs=11 "
                "--tpm2-public-key=/var/lib/test-pcr/public.pem ")
      # An initrd-only authorization must not pass the late-userspace safety check.
      machine.succeed("umask 077; ukify --json=short inspect /var/lib/probe-images/probe-base.efi | "
                      "python3 -c 'import json,pathlib,sys; "
                      "pathlib.Path(\"/run/initrd-only.json\").write_text(json.load(sys.stdin)[\".pcrsig\"][\"text\"])'")
      machine.fail(enroll + "--tpm2-signature=/run/initrd-only.json")
      machine.succeed("rm /run/initrd-only.json")
      assert not json.loads(machine.succeed("cryptsetup luksDump --dump-json-metadata /dev/vdb"))["tokens"]
      machine.succeed("umask 077; /run/current-system/systemd/lib/systemd/systemd-measure "
                      "sign --current --phase=: --bank=sha256 "
                      "--private-key=/var/lib/test-pcr/private.pem "
                      "--public-key=/var/lib/test-pcr/public.pem > /run/enrollment-only.json")
      machine.succeed(enroll + "--tpm2-signature=/run/enrollment-only.json")
      machine.succeed("rm /run/enrollment-only.json")
      tokens = json.loads(machine.succeed("cryptsetup luksDump --dump-json-metadata /dev/vdb"))["tokens"]
      assert len(tokens) == 1, "expected exactly one TPM token"
      token = next(iter(tokens.values()))
      assert token["type"] == "systemd-tpm2"
      assert token["tpm2-pcrs"] == [7, 12]
      assert token["tpm2-pcr-bank"] == "sha256"
      assert token["tpm2_pubkey_pcrs"] == [11]
      # v260 omits these flags when false (tpm2_make_luks2_json).
      assert token.get("tpm2-pin", False) is False
      assert token.get("tpm2_pcrlock", False) is False
      log.info("VM TPM policy verified: SHA256 PCR7+12, signed PCR11, no PIN/PCRLock")
      machine.succeed("cp /var/lib/probe-images/probe-luks.efi "
                      "/var/lib/probe-images/probe-updated.efi /boot/EFI/Linux/")
      select_probe_image(machine, "probe-luks.efi")
      cold_restart(machine)
      # No passphrase input, keyfile or preopened mapper for this positive boot.
      verify_uki_boot(machine, "luks", "${luks}")
      machine.succeed("findmnt -n -o SOURCE / | grep -Fx /dev/mapper/cryptroot")
      machine.succeed("test -s /probe-root-marker")
      # The initrd unit is dropped after switch-root; check its boot-time result.
      assert "Finished Cryptography Setup for cryptroot" in machine.get_console_log()
      assert "Please enter passphrase" not in machine.get_console_log()
      assert machine.succeed("tpm2_pcrread sha256:12") == pcr12_normal

      select_probe_image(machine, "probe-updated.efi")
      cold_restart(machine)
      verify_uki_boot(machine, "updated", "${updated}")
      machine.succeed("findmnt -n -o SOURCE / | grep -Fx /dev/mapper/cryptroot")
      select_probe_image(machine, "probe-luks.efi")
      cold_restart(machine)
      verify_uki_boot(machine, "luks", "${luks}")

      # Trusted UEFI signer, WRONG policy key: boot may run but cannot auto-unlock.
      make_test_keys(machine, "/var/lib/test-pcr-wrong")
      log.info(machine.succeed("df -B1 /boot; du -sk /boot/EFI/*"))
      # The bootstrap-only image is no longer needed; retain both encrypted UKIs.
      machine.succeed("rm /boot/EFI/Linux/probe-base.efi")
      build_guest_uki(machine, "${luks}", "/var/lib/test-pcr-wrong",
                      "/var/lib/probe-images/probe-wrong.efi", marker="wrong")
      machine.succeed("cp /var/lib/probe-images/probe-wrong.efi /boot/EFI/Linux/")
      select_probe_image(machine, "probe-wrong.efi")
      cold_restart(machine)
      recover_at_console(machine)
      verify_uki_boot(machine, "wrong", "${luks}")
      machine.succeed("findmnt -n -o SOURCE / | grep -Fx /dev/mapper/cryptroot")

      # Same approved UKI/policy signature, different external credential state.
      machine.succeed("mkdir -p /boot/EFI/Linux/probe-luks.efi.extra.d; "
                      "printf vm-only-unapproved-credential > "
                      "/boot/EFI/Linux/probe-luks.efi.extra.d/probe.cred")
      select_probe_image(machine, "probe-luks.efi")
      cold_restart(machine)
      recover_at_console(machine)
      verify_uki_boot(machine, "luks", "${luks}")
      pcr12_credential = machine.succeed("tpm2_pcrread sha256:12")
      log.info("VM unexpected-credential SHA256 PCR12:\n" + pcr12_credential)
      assert pcr12_credential != pcr12_normal
      machine.succeed("rm /boot/EFI/Linux/probe-luks.efi.extra.d/probe.cred")
      cold_restart(machine)
      verify_uki_boot(machine, "luks", "${luks}")
      assert machine.succeed("tpm2_pcrread sha256:12") == pcr12_normal

      # Isolated firmware refusal: there is no authorized fallback UKI or entry.
      unsigned.start(allow_reboot=True)
      unsigned.wait_for_unit("multi-user.target")
      unsigned.succeed("sbctl create-keys")
      make_test_keys(unsigned, "/var/lib/test-pcr")
      unsigned.succeed("mkdir -p /var/lib/probe-images /boot/EFI/Linux")
      build_guest_uki(unsigned, "${unsignedBase}", "/var/lib/test-pcr",
                      "/var/lib/probe-images/probe-unsigned.efi", sign=False, marker="unsigned")
      unsigned.fail("sbverify --cert /var/lib/sbctl/keys/db/db.pem "
                    "/var/lib/probe-images/probe-unsigned.efi")
      unsigned.succeed("sbctl sign /boot/EFI/systemd/systemd-bootx64.efi")
      unsigned.succeed("sbctl sign /boot/EFI/BOOT/BOOTX64.EFI")
      unsigned.succeed("cp /var/lib/probe-images/probe-unsigned.efi /boot/EFI/Linux/")
      select_probe_image(unsigned, "probe-unsigned.efi")
      # Disposable OVMF guest only; no host firmware keys are touched.
      unsigned.succeed("sbctl enroll-keys --yes-this-might-brick-my-machine")
      cold_restart(unsigned)
      # This pinned OVMF returns EFI_ACCESS_DENIED, not EFI_SECURITY_VIOLATION.
      def unsigned_refused(_last_try):
          console = unsigned.get_console_log()
          return (re.search(r"Error loading EFI binary .*probe-unsigned\.efi: Access denied", console)
                  and "No bootable option or device was found" in console)

      driver_retry(unsigned_refused, 60)
      unsigned.screenshot("unsigned-uki-refused")
      assert "Linux version " not in unsigned.get_console_log()
    '';
}
