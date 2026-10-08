{
  pkgs,
  disko,
  impermanence,
  disableRollback ? false,
  enableTpm ? false,
  extraPcrScript ? "",
}:
let
  inherit (pkgs) lib;
  package = pkgs.callPackage ../pkgs/secure-uki { };
  # VM-only second installer package version; actual publication implementation
  # stays unchanged, and both generations use the guarded production CLI.
  packageV2 = package.overrideAttrs (old: {
    version = "0.1.1";
    src = pkgs.runCommand "vm-only-secure-uki-v2-source" { } ''
      cp -r ${old.src} "$out"
      chmod -R u+w "$out"
      substituteInPlace "$out/pyproject.toml" --replace-fail 'version = "0.1.0"' 'version = "0.1.1"'
    '';
  });
  layout = lib.recursiveUpdate (import ../systems/x86_64-linux/dancer/disk-config.nix) {
    disko.devices.disk.nvme0n1.content.partitions = {
      ESP.size = "512M";
      luks.content.content.subvolumes."/swap".swap.swapfile.size = "256M";
    };
  };
  diskoLib = pkgs.callPackage (disko.outPath + "/lib") {
    eval-config = import (pkgs.path + "/nixos/lib/eval-config.nix");
    makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
    qemu-common = import (pkgs.path + "/nixos/lib/qemu-common.nix");
  };
  bootLayout = diskoLib.testLib.prepareDiskoConfig layout diskoLib.testLib.devices;
  evaluate =
    extra:
    import (pkgs.path + "/nixos/lib/eval-config.nix") {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        bootLayout
        impermanence.nixosModules.impermanence
        ../systems/profiles/impermanence
        ../systems/profiles/boot/secure-uki
        (pkgs.path + "/nixos/modules/testing/test-instrumentation.nix")
        (pkgs.path + "/nixos/modules/profiles/qemu-guest.nix")
        {
          nixpkgs.pkgs = pkgs;
          networking.hostName = "dancer-vm";
          system.stateVersion = "26.05";
          boot.secureUki.enable = true;
          boot.initrd.systemd.enable = true;
          boot.initrd.luks.devices.encrypted.crypttabExtraOpts = lib.optionals enableTpm [
            "tpm2-device=auto"
          ];
          boot.initrd.availableKernelModules = lib.optionals enableTpm [
            "tpm_tis"
            "tpm_crb"
          ];
          boot.initrd.systemd.services.vm-pcr-observer = lib.mkIf enableTpm {
            requiredBy = [ "systemd-cryptsetup@encrypted.service" ];
            # Observe the real cryptsetup barrier; do NOT add an ordering edge
            # to pcrphase itself that could conceal missing production ordering.
            after = [ "cryptsetup-pre.target" ];
            before = [ "systemd-cryptsetup@encrypted.service" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              systemctl is-active --quiet systemd-pcrphase-initrd.service
              test "$(systemctl is-enabled systemd-tpm2-setup-early.service)" = masked
              test "$(systemctl is-enabled systemd-tpm2-setup.service)" = masked
              echo VM_SRK_SETUP_MASKED_INITRD
              if test -s /vm-update-marker; then echo VM_CHANGED_INITRD; fi
              if test -s /.extra/tpm2-pcr-signature.json && test -s /.extra/tpm2-pcr-public-key.pem; then
                mkdir -p /run/vm-initrd-evidence
                cp /.extra/tpm2-pcr-signature.json /.extra/tpm2-pcr-public-key.pem /run/vm-initrd-evidence/
                echo VM_PCR_HANDOFF_AFTER_ENTER_INITRD
              else
                echo VM_PCR_HANDOFF_MISSING
              fi
            '';
          };
          boot.initrd.systemd.services.root-roolback.wantedBy = lib.mkIf disableRollback (lib.mkForce [ ]);
          boot.loader.efi.canTouchEfiVariables = true;
          fileSystems."/persist".neededForBoot = true;
          services.openssh.enable = true;
          documentation.enable = false;
          hardware.enableAllFirmware = false;
          environment.systemPackages = [
            pkgs.python3
            pkgs.openssl
            pkgs.sbctl
            pkgs.cryptsetup
            pkgs.util-linux
            pkgs.btrfs-progs
            pkgs.sbsigntool
          ]
          ++ lib.optionals enableTpm [
            pkgs.tpm2-tools
            pkgs.efitools
            pkgs.binutils
            pkgs.e2fsprogs
          ];
        }
        extra
      ];
    };
  a = evaluate { boot.secureUki.bootstrapLabel = "dancer-uki-bootstrap"; };
  b = evaluate {
    boot.secureUki.bootstrapLabel = "dancer-uki-ready";
    boot.loader.external.installHook = lib.mkForce (
      pkgs.writeShellScript "vm-v2-secure-uki-install" ''
        set -eu
        test "$#" -eq 1
        exec ${packageV2}/bin/secure-uki install "$1"
      ''
    );
    system.activationScripts.vm-fail = {
      deps = [ "specialfs" ];
      text = ''
        if test -e /persist/vm-activation-fail; then
          echo VM_ONLY_ACTIVATION_FAILURE >&2
          exit 1
        fi
      '';
    };
  };
  stock = evaluate {
    boot.secureUki.enable = lib.mkForce false;
    boot.loader.systemd-boot.enable = true;
    system.nixos.label = "vm-stock-unsafe";
  };
  c = evaluate {
    boot.secureUki.bootstrapLabel = "vm-pcr-update";
    boot.initrd.systemd.contents."/vm-update-marker".source =
      pkgs.writeText "vm-update-marker" "VM ONLY initrd update";
  };
  cTop = c.config.system.build.toplevel;
  fixtures = [
    aTop
    bTop
    stockTop
  ]
  ++ lib.optional enableTpm cTop;
  aTop = a.config.system.build.toplevel;
  bTop = b.config.system.build.toplevel;
  stockTop = stock.config.system.build.toplevel;
  ovmf = (pkgs.OVMFFull.override { secureBoot = true; }).fd;
in
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "dancer-secure-uki";
  disko-config = layout;
  testBoot = false; # Own signed boot lifecycle below, not Disko's unsigned boot/keyfile fixture.
  extraInstallerConfig = {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    virtualisation = {
      useBootLoader = true;
      useEFIBoot = true;
      mountHostNixStore = true; # Rescue only; installed encrypted store is copied, never shared.
      memorySize = 3072;
    };
    environment.systemPackages = [
      pkgs.sbctl
      pkgs.openssl
      pkgs.python3
      pkgs.cryptsetup
      pkgs.sbsigntool
    ];
  };
  postDisko = ''
    # All formatting/installing occurs ONLY on the disposable guest disk /dev/vdb.
    machine.succeed("printf vm-recovery-only > /run/vm-recovery.key; chmod 600 /run/vm-recovery.key")
    machine.succeed("cryptsetup luksAddKey --key-file /tmp/secret.key /dev/vdb2 /run/vm-recovery.key")
    machine.succeed("cryptsetup luksKillSlot --key-file /run/vm-recovery.key /dev/vdb2 0")
    machine.succeed("rm /run/vm-recovery.key")
    machine.succeed("nix-store --load-db < ${
      pkgs.closureInfo {
        rootPaths = fixtures;
      }
    }/registration")
    # Locally built, unsigned NAR test fixtures only; this does NOT bypass any
    # EFI/capsule signature, change production caches or trust remote content.
    machine.succeed("nix --extra-experimental-features nix-command copy --no-check-sigs --to 'local?root=/mnt' ${lib.concatStringsSep " " (map toString fixtures)}")
    machine.succeed("mkdir -p /mnt/etc /mnt/nix/var/nix/profiles; touch /mnt/etc/NIXOS; nix-env -p /mnt/nix/var/nix/profiles/system --set ${aTop}")
    ${lib.optionalString enableTpm ''
      machine.succeed("ln -s ${cTop} /mnt/nix/var/nix/gcroots/vm-fixture-c")
    ''}
    machine.succeed("nixos-enter --root /mnt -- ${aTop}/activate")
    machine.succeed("mkdir -p /mnt/persist/var/lib/sbctl /mnt/persist/var/lib/secure-uki /mnt/var/lib/sbctl /mnt/var/lib/secure-uki; chmod 700 /mnt/persist/var/lib/{sbctl,secure-uki}; mount --bind /mnt/persist/var/lib/sbctl /mnt/var/lib/sbctl; mount --bind /mnt/persist/var/lib/secure-uki /mnt/var/lib/secure-uki")
    esp_before_keys = machine.succeed("find /mnt/boot -type f -exec sha256sum {} + | sort")
    machine.fail("NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -- ${aTop}/bin/switch-to-configuration boot")
    assert machine.succeed("find /mnt/boot -type f -exec sha256sum {} + | sort") == esp_before_keys
    machine.succeed("test ! -e /mnt/var/lib/secure-uki/manifest.json")
    machine.succeed("nixos-enter --root /mnt -- sbctl create-keys")
    machine.succeed("nixos-enter --root /mnt -- sh -c 'install -d -m 0700 /var/lib/secure-uki/pcr-signing; openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out /var/lib/secure-uki/pcr-signing/private.pem; chmod 600 /var/lib/secure-uki/pcr-signing/private.pem; openssl pkey -in /var/lib/secure-uki/pcr-signing/private.pem -pubout -out /var/lib/secure-uki/pcr-signing/public.pem'")
    machine.succeed("NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -- ${aTop}/bin/switch-to-configuration boot")
    machine.succeed("sync")
  '';
  extraTestScript = ''
    import shutil
    SECURE_UKI_PYTHONPATH = "${package}/${pkgs.python3.sitePackages}"
    ${builtins.replaceStrings [ "import shlex\n" ] [ "" ] (
      builtins.readFile ./secure-uki-vm-helpers.py
    )}
    # Bind the shared recovery helper to the real Disko mapper for this fixture.
    from functools import partial
    root_recovery = partial(recover_at_console, mapper="encrypted")
    def recover_at_console(vm):
        root_recovery(vm)
        # multi-user is reached before Type=exec confirmation finishes. Observe
        # completion before intentionally starting another shared-lock writer.
        vm.wait_until_succeeds("test $(systemctl show secure-uki-confirm -p SubState --value) = exited")
    installer = machine
    installer.shutdown()
    installer.wait_for_shutdown()
    variables = installer.state_dir / "signed-root-vars.fd"
    shutil.copyfile("${ovmf}/FV/OVMF_VARS.fd", variables)
    command = shlex.split("${pkgs.qemu_test}/bin/qemu-system-x86_64 -machine q35,accel=kvm:tcg,smm=on -global driver=cfi.pflash01,property=secure,value=on -cpu max")
    command += ["-m", "3072", "-drive", "file=" + str(installer.state_dir / "empty0.qcow2") + ",if=virtio,format=qcow2",
                "-drive", "if=pflash,format=raw,unit=0,readonly=on,file=${ovmf}/FV/OVMF_CODE.fd",
                "-drive", "if=pflash,format=raw,unit=1,file=" + str(variables)]
    tpm_start = []
    ${lib.optionalString enableTpm ''
      tpm_directory = installer.state_dir / "signed-root-tpm"
      tpm_directory.mkdir()
      tpm_start = ["${pkgs.swtpm}/bin/swtpm", "socket", "--tpm2", "--tpmstate", "dir=" + str(tpm_directory),
                   "--ctrl", "type=unixio,path=" + str(tpm_directory / "socket.ctrl"),
                   "--flags", "not-need-init", "--daemon"]
      command += ["-chardev", "socket,id=chrtpm,path=" + str(tpm_directory / "socket.ctrl"),
                  "-tpmdev", "emulator,id=tpm0,chardev=chrtpm", "-device", "tpm-tis,tpmdev=tpm0"]
    ''}
    # QEMU disconnect terminates swtpm: restart its process on every cold boot,
    # retaining the SAME emulator state directory (never clear/reprovision).
    start_command = (shlex.join(tpm_start) + " && exec " if tpm_start else "") + shlex.join(command)
    machine = create_machine(start_command=start_command, name="signed_root")
    driver.machines_qemu.append(machine)
    try:
        machine.start()
    except BaseException:
        if machine.process and machine.process.stdout:
            print(machine.process.stdout.read().decode(errors="replace"))
        raise
    recover_at_console(machine)
    machine.succeed("test $(readlink -f /run/booted-system) = ${aTop}")
    ${lib.optionalString enableTpm ''
      # Fresh emulator, real measured UKI/manual unlock, no cryptenroll call.
      # Capability reads are non-mutating; setup must not have created an SRK.
      assert not machine.succeed("tpm2_getcap handles-persistent").strip(), "automatic SRK provisioning occurred before any TPM enrollment"
      for unit in ("systemd-tpm2-setup-early", "systemd-tpm2-setup"):
          status, output = machine.execute("systemctl is-enabled " + unit + ".service")
          assert status != 0 and output.strip() == "masked", "userspace TPM setup is not masked"
          machine.fail("systemctl start " + unit + ".service")
      assert "VM_SRK_SETUP_MASKED_INITRD" in machine.get_console_log()
      assert not machine.succeed("tpm2_getcap handles-persistent").strip(), "explicit setup activation bypassed mask"
    ''}
    machine.succeed("findmnt -T /nix/store -n -o SOURCE,FSTYPE | grep -F /dev/mapper/encrypted | grep -F btrfs")
    # Actual stock rollback installs an unsigned manager even with signed UKIs
    # present. Observe hazard while Secure Boot is still disabled, then restore.
    machine.succeed("NIXOS_INSTALL_BOOTLOADER=1 ${stockTop}/bin/switch-to-configuration boot")
    assert machine.execute("sbverify --cert /var/lib/sbctl/keys/db/db.pem /boot/EFI/systemd/systemd-bootx64.efi")[0] != 0, "stock-installer hazard was not reproduced"
    machine.fail("NIXOS_INSTALL_BOOTLOADER=1 ${aTop}/bin/switch-to-configuration boot")
    recovery_state = json.loads(machine.succeed("cat /var/lib/secure-uki/manifest.json"))
    manager_hash = recovery_state["images"][recovery_state["default"]]["bootmanager_sha256"]
    backup = "/boot/EFI/secure-uki/systemd-boot-" + manager_hash + ".efi"
    machine.succeed("sbverify --cert /var/lib/sbctl/keys/db/db.pem " + backup)
    assert machine.succeed("sha256sum " + backup).split()[0] == manager_hash
    machine.succeed("cp " + backup + " /boot/EFI/systemd/systemd-bootx64.efi; cp " + backup + " /boot/EFI/BOOT/BOOTX64.EFI; sync")
    machine.succeed("NIXOS_INSTALL_BOOTLOADER=1 ${aTop}/bin/switch-to-configuration boot")
    machine.succeed("rm -f /boot/loader/entries/*.conf")
    machine.succeed("sbctl enroll-keys --yes-this-might-brick-my-machine")
    cold_restart(machine)
    recover_at_console(machine)
    machine.succeed("bootctl status | grep -E 'Secure Boot: enabled'")
    machine.succeed("test $(readlink -f /run/booted-system) = ${aTop}")
    machine.wait_until_succeeds("python3 -c 'import json; m=json.load(open(\"/var/lib/secure-uki/manifest.json\")); assert m[\"known_good\"] == m[\"default\"]'")
    machine.succeed("touch /root-reset-probe /home/uki-home-probe /persist/uki-persist-probe /nix/uki-nix-probe")
    key_before = machine.succeed("sha256sum /var/lib/sbctl/keys/db/db.key /var/lib/secure-uki/pcr-signing/private.pem")
    ssh_before = machine.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub")
    cold_restart(machine)
    recover_at_console(machine)
    assert machine.execute("test ! -e /root-reset-probe")[0] == 0, "production root rollback was not executed"
    machine.succeed("test -e /home/uki-home-probe; test -e /persist/uki-persist-probe; test -e /nix/uki-nix-probe")
    assert machine.succeed("sha256sum /var/lib/sbctl/keys/db/db.key /var/lib/secure-uki/pcr-signing/private.pem") == key_before
    assert machine.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub") == ssh_before
    header = json.loads(machine.succeed("cryptsetup luksDump --dump-json-metadata /dev/vda2"))
    assert not header["tokens"] and header["keyslots"], "manual recovery must remain, with no TPM token"
    machine.succeed("touch /persist/vm-activation-fail")
    status, output = machine.execute("${bTop}/bin/switch-to-configuration switch")
    assert status != 0 and "VM_ONLY_ACTIVATION_FAILURE" in machine.get_console_log(), output
    state = json.loads(machine.succeed("cat /var/lib/secure-uki/manifest.json"))
    assert state["known_good"] != state["default"], "activation must not confirm an unbooted generation"
    machine.succeed("rm /persist/vm-activation-fail; ${aTop}/bin/switch-to-configuration switch")
    machine.succeed("${bTop}/bin/switch-to-configuration boot")
    state = json.loads(machine.succeed("cat /var/lib/secure-uki/manifest.json"))
    machine.succeed("printf vm-unrelated-gc-sentinel > /run/gc-sentinel")
    unrelated = machine.succeed("nix-store --add /run/gc-sentinel").strip()
    machine.succeed("findmnt -T /nix/store -n -o SOURCE,FSTYPE | grep -F /dev/mapper/encrypted | grep -F btrfs")
    machine.succeed("nix-store --gc") # Guest-only actual encrypted store, NEVER Framework.
    machine.fail("test -e " + unrelated)
    for entry in (state["default"], state["known_good"]):
        machine.succeed("test -e " + state["images"][entry]["closure"] + "/init")
        machine.succeed("test -L /var/lib/secure-uki/gc-roots/" + entry)
    cold_restart(machine)
    recover_at_console(machine)
    machine.succeed("test $(readlink -f /run/booted-system) = ${bTop}")
    machine.wait_until_succeeds("python3 -c 'import json; m=json.load(open(\"/var/lib/secure-uki/manifest.json\")); assert m[\"known_good\"] == m[\"default\"]'")
    machine.succeed("${aTop}/bin/switch-to-configuration boot")
    cold_restart(machine)
    recover_at_console(machine)
    machine.succeed("test $(readlink -f /run/booted-system) = ${aTop}")
    # Isolate each forbidden image: no authorized UKI remains on the ESP, so
    # fallback cannot silently turn a refusal into an apparently successful boot.
    for kind in ("unsigned", "tampered"):
        state = json.loads(machine.succeed("cat /var/lib/secure-uki/manifest.json"))
        default = state["default"]
        archive = "/persist/refusal-" + kind
        machine.succeed("cp /boot/EFI/Linux/" + default + " /run/refused.efi")
        if kind == "unsigned":
            machine.succeed("sbattach --remove /run/refused.efi")
        else:
            mutate = "import pathlib,struct; p=pathlib.Path('/run/refused.efi'); d=bytearray(p.read_bytes()); pe=struct.unpack_from('<I',d,60)[0]; n=struct.unpack_from('<H',d,pe+6)[0]; opt=struct.unpack_from('<H',d,pe+20)[0]; headers=pe+24+opt; s=next(headers+40*i for i in range(n) if bytes(d[headers+40*i:headers+40*i+8]).rstrip(bytes([0]))==b'.osrel'); raw=struct.unpack_from('<I',d,s+20)[0]; d[raw]^=1; p.write_bytes(d)"
            guest_command(machine, ["python3", "-c", mutate])
        machine.fail("sbverify --cert /var/lib/sbctl/keys/db/db.pem /run/refused.efi")
        machine.succeed("mkdir -p " + archive + "; mv /boot/EFI/Linux/*.efi " + archive + "; cp /run/refused.efi /boot/EFI/Linux/probe-refused.efi")
        select_probe_image(machine, "probe-refused.efi")
        machine.succeed("sync")
        cold_restart(machine)
        def firmware_refusal(_last_try):
            return "Access denied" in machine.get_console_log()
        driver_retry(firmware_refusal, 90)
        assert "Linux version" not in machine.get_console_log(), "a different image silently booted"
        print("Isolated " + kind + " UKI: firmware EFI_ACCESS_DENIED; Linux never starts")
        machine.send_monitor_command("quit")
        machine.wait_for_shutdown()
        # Existing rescue guest, same disk, NO formatting/reinstall or firmware
        # disable/TPM clearing. Restore ONLY already verified signed artifacts.
        installer.start()
        installer.wait_for_unit("multi-user.target")
        installer.succeed("printf vm-recovery-only | cryptsetup open --key-file=- /dev/vdb2 encrypted")
        installer.succeed("mkdir -p /run/recovery-esp /run/recovery-persist; mount /dev/vdb1 /run/recovery-esp; mount -o subvol=/persist /dev/mapper/encrypted /run/recovery-persist")
        restore = "/run/recovery-persist/refusal-" + kind + "/" + default
        installer.succeed("sbverify --cert /run/recovery-persist/var/lib/sbctl/keys/db/db.pem " + restore)
        assert installer.succeed("sha256sum " + restore).split()[0] == state["images"][default]["sha256"]
        installer.succeed("rm /run/recovery-esp/EFI/Linux/probe-refused.efi; cp /run/recovery-persist/refusal-" + kind + "/*.efi /run/recovery-esp/EFI/Linux/")
        guest_command(installer, ["sh", "-c", "printf 'timeout 2\\neditor no\\ndefault %s\\n' \"$1\" > /run/recovery-esp/loader/loader.conf", "restore", default])
        installer.succeed("sync; umount /run/recovery-esp /run/recovery-persist; cryptsetup close encrypted")
        installer.shutdown()
        installer.wait_for_shutdown()
        machine.start()
        recover_at_console(machine)
        machine.succeed("test $(readlink -f /run/booted-system) = ${aTop}; bootctl status | grep -E 'Secure Boot: enabled'")
    machine.succeed("test -e /home/uki-home-probe; test -e /persist/uki-persist-probe; test -e /nix/uki-nix-probe")
    assert machine.succeed("sha256sum /var/lib/sbctl/keys/db/db.key /var/lib/secure-uki/pcr-signing/private.pem") == key_before
    assert machine.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub") == ssh_before
    header_after = json.loads(machine.succeed("cryptsetup luksDump --dump-json-metadata /dev/vda2"))
    assert not header_after["tokens"] and header_after["keyslots"] == header["keyslots"]
    print("Production encrypted root rollback, manual signed boot, persistence, activation recovery, GC and isolated refusal/recovery passed")
    ${lib.optionalString enableTpm ''
      A_CLOSURE = "${aTop}"
      B_CLOSURE = "${bTop}"
      C_CLOSURE = "${cTop}"
      ${extraPcrScript}
      # QEMU owns swtpm's single control connection. Closing that connection
      # stops the daemon; a second ioctl client while QEMU is live would block.
      machine.shutdown()
      machine.wait_for_shutdown()
      driver_retry(lambda _last_try: not (tpm_directory / "socket.ctrl").exists(), 30)
    ''}
  '';
}
