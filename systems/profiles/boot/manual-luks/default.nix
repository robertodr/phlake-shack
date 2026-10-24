{ config, lib, ... }:
{
  # Permanent Dancer policy; firmware Secure Boot is disabled separately by a human.
  # Retain existing signing/recovery state and keys; do not erase or enroll anything.
  assertions = [
    {
      assertion = config.networking.hostName == "dancer";
      message = "the manual-LUKS rollback profile is restricted to Dancer";
    }
    {
      assertion =
        config.fileSystems."/persist".neededForBoot
        && config.fileSystems."/persist".fsType == "btrfs"
        && config.fileSystems."/persist".device == "/dev/mapper/encrypted";
      message = "manual rollback must retain boot-critical encrypted Btrfs persistence";
    }
    {
      assertion = builtins.attrNames config.boot.initrd.luks.devices == [ "encrypted" ];
      message = "manual rollback expects Dancer's existing single encrypted root";
    }
  ];

  boot = {
    secureUki = {
      enable = lib.mkForce false;
      issuerMaintenance = lib.mkForce false;
      parentMaintenance = lib.mkForce false;
      enrollmentMaintenance = lib.mkForce false;
      bootstrapLabel = lib.mkForce null;
    };
    loader = {
      external.enable = lib.mkForce false;
      grub.enable = lib.mkForce false;
      systemd-boot = {
        enable = lib.mkForce true;
        # No generation-count limit. The stock installer still has ESP garbage
        # collection: this is NOT a guarantee that existing entries survive.
        configurationLimit = lib.mkForce null;
      };
    };
    initrd = {
      secrets = lib.mkForce { };
      luks.devices.encrypted = {
        keyFile = lib.mkForce null;
        tryEmptyPassphrase = lib.mkForce false;
        # No TPM/FIDO/PKCS#11/headless crypttab opt-ins; ask for the passphrase.
        crypttabExtraOpts = lib.mkForce [ ];
      };
      systemd = {
        enable = lib.mkForce true;
        tpm2 = {
          enable = lib.mkForce false;
          pcrphases.enable = lib.mkForce false;
        };
        services = {
          systemd-tpm2-setup-early.enable = lib.mkForce false;
          systemd-tpm2-setup.enable = lib.mkForce false;
        };
      };
    };
  };

  systemd = {
    tpm2 = {
      enable = lib.mkForce false;
      pcrphases.enable = lib.mkForce false;
    };
    # Keep these masks after opting out of secure-uki; merely removing that
    # module's config would drop its protection against default SRK provisioning.
    services = {
      systemd-tpm2-setup-early.enable = lib.mkForce false;
      systemd-tpm2-setup.enable = lib.mkForce false;
      secure-uki-confirm.enable = lib.mkForce false;
      secure-uki-fwupd-sign.enable = lib.mkForce false;
    };
  };

  # Impermanence must not drop these bindings when secureUki.enable becomes false.
  # They are retained evidence/recovery, not inputs to the new boot path.
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/sbctl";
      mode = "0700";
    }
    {
      directory = "/var/lib/secure-uki";
      mode = "0700";
    }
  ];
}
