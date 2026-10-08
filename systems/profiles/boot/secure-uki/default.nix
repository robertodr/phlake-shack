{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.boot.secureUki;
  package = pkgs.callPackage ../../../../pkgs/secure-uki { };
  ukify = pkgs.writeShellScriptBin "ukify" ''
    exec ${pkgs.systemdUkify}/lib/systemd/ukify --stub=${pkgs.systemd}/lib/systemd/boot/efi/linuxx64.efi.stub "$@"
  '';
  installer = pkgs.writeShellScript "secure-uki-install" ''
    set -eu
    test "$#" -eq 1
    exec ${package}/bin/secure-uki install "$1"
  '';
  helper = "${config.services.fwupd.package.fwupd-efi}/libexec/fwupd/efi/fwupdx64.efi";
  runtime = {
    version = 1;
    esp = "/boot";
    state_dir = "/var/lib/secure-uki";
    state_filesystem = "btrfs";
    encrypted_device = "/dev/mapper/encrypted";
    keys = {
      db_key = "/var/lib/sbctl/keys/db/db.key";
      db_cert = "/var/lib/sbctl/keys/db/db.pem";
      pcr_private = "/var/lib/secure-uki/pcr-signing/private.pem";
      pcr_public = "/var/lib/secure-uki/pcr-signing/public.pem";
    };
    tools = {
      ukify = "${ukify}/bin/ukify";
      measure = "${pkgs.systemd}/lib/systemd/systemd-measure";
      bootctl = "${pkgs.systemd}/bin/bootctl";
      systemctl = "${pkgs.systemd}/bin/systemctl";
      sbsign = "${pkgs.sbsigntool}/bin/sbsign";
      sbverify = "${pkgs.sbsigntool}/bin/sbverify";
      nix_store = "${config.nix.package}/bin/nix-store";
      findmnt = "${pkgs.util-linux}/bin/findmnt";
      cryptsetup = "${pkgs.cryptsetup}/bin/cryptsetup";
    };
  };
in
{
  options.boot.secureUki = {
    enable = lib.mkEnableOption "target-local signed UKI boot installation";
    bootstrapLabel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional UKI-aware bootstrap generation label.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.boot.loader.efi.efiSysMountPoint == "/boot";
        message = "secure UKIs require the fixed /boot ESP";
      }
      {
        assertion = config.boot.initrd.systemd.enable;
        message = "secure UKIs require the systemd initrd";
      }
      {
        assertion =
          config.fileSystems."/persist".neededForBoot && config.fileSystems."/persist".fsType == "btrfs";
        message = "secure UKIs require boot-critical encrypted Btrfs persistence";
      }
      {
        assertion = !config.boot.loader.grub.enable;
        message = "secure UKIs cannot share boot installation with GRUB";
      }
      {
        assertion =
          !config.services.fwupd.enable
          || builtins.elem "-Defi_app_location=/run/fwupd-efi" (
            config.services.fwupd.package.mesonFlags or [ ]
          );
        message = "secure UKIs require the selected fwupd to use /run/fwupd-efi (the pinned Dancer 2.1.6 package)";
      }
    ];
    boot = {
      loader = {
        external = {
          enable = true;
          installHook = installer;
        };
        systemd-boot.enable = lib.mkForce false;
        supportsInitrdSecrets = lib.mkForce false;
      };
      bootspec.enable = true;
      initrd.systemd = {
        tpm2 = {
          enable = true;
          pcrphases.enable = true;
        };
        services = {
          systemd-tpm2-setup-early.enable = lib.mkForce false;
          systemd-tpm2-setup.enable = lib.mkForce false;
        };
      };
    };
    systemd = {
      tpm2.pcrphases.enable = true;
      # Measured boot enables the upstream generator's SRK setup jobs even without
      # a LUKS TPM token. They can create a persistent parent and silently fall back
      # from ECC to RSA. Mask BOTH entrypoints in BOTH stages, not just wantedBy:
      # PCR measurement/authorized unlock remain available, key provisioning does
      # not. Any future physical ECC provisioning needs separate explicit approval.
      services = {
        systemd-tpm2-setup-early.enable = lib.mkForce false;
        systemd-tpm2-setup.enable = lib.mkForce false;
        secure-uki-confirm = {
          description = "Confirm the actually booted signed UKI after system readiness";
          wantedBy = [ "multi-user.target" ];
          # DefaultDependencies=false avoids the readiness cycle; restore explicit
          # shutdown ordering so no confirmation process outlives persistence.
          conflicts = [ "shutdown.target" ];
          before = [ "shutdown.target" ];
          after = [
            "multi-user.target"
            "local-fs.target"
            "systemd-user-sessions.service"
          ];
          unitConfig = {
            # A first switch still runs on the ordinary booted closure. Do not
            # mark that healthy migration failed or retry confirming it. Once a
            # UKI-aware closure actually boots, the CLI still verifies stub,
            # selected image/closure and readiness before any confirmation.
            ConditionPathExists = "/run/booted-system/etc/secure-uki.json";
            DefaultDependencies = false;
            RequiresMountsFor = [
              "/boot"
              "/var/lib/sbctl"
              "/var/lib/secure-uki"
            ];
          };
          serviceConfig = {
            # Type=exec ends the start job before checking is-system-running. A oneshot
            # itself keeps the system 'starting', preventing truthful confirmation.
            Type = "exec";
            ExecStart = "${package}/bin/secure-uki confirm-boot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = "30s";
            UMask = "0077";
          };
        };
        secure-uki-fwupd-sign = lib.mkIf config.services.fwupd.enable {
          description = "Reconstruct and verify the selected fwupd signed EFI helper";
          after = [ "systemd-tmpfiles-setup.service" ];
          before = [ "fwupd.service" ];
          unitConfig.RequiresMountsFor = [
            "/boot"
            "/var/lib/sbctl"
            "/var/lib/secure-uki"
          ];
          serviceConfig = {
            # Do not cache an active oneshot: every daemon start/restart signs again.
            Type = "oneshot";
            ExecStart = "${package}/bin/secure-uki-fwupd ${helper}";
            UMask = "0077";
          };
        };
        fwupd = lib.mkIf config.services.fwupd.enable {
          requires = [ "secure-uki-fwupd-sign.service" ];
          after = [ "secure-uki-fwupd-sign.service" ];
        };
      };
      tmpfiles.rules = lib.mkIf config.services.fwupd.enable [
        "C+ /run/fwupd-efi - - - - ${config.services.fwupd.package.fwupd-efi}/libexec/fwupd/efi"
      ];
    };
    services.fwupd.uefiCapsuleSettings = lib.mkIf config.services.fwupd.enable {
      DisableShimForSecureBoot = true;
    };
    system.nixos.label = lib.mkIf (cfg.bootstrapLabel != null) cfg.bootstrapLabel;
    environment = {
      systemPackages = [ package ];
      etc."secure-uki.json".text = builtins.toJSON runtime;
      persistence."/persist".directories = [
        {
          directory = "/var/lib/sbctl";
          mode = "0700";
        }
        {
          directory = "/var/lib/secure-uki";
          mode = "0700";
        }
      ];
    };
  };
}
