{
  config,
  lib,
  pkgsUnstable,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../../users/roberto
    ../../profiles/base
    ../../profiles/development
    ../../profiles/impermanence
    ../../profiles/services/openssh/lan-only.nix
  ];

  boot = {
    resumeDevice = "";
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd.systemd.enable = true;
  };

  networking.hostName = "dancer";

  services = {
    # 2.1.6 fixes the JCat entry limit for Lenovo's KEK 2011 -> 2023 update.
    # Select both daemon and client from our existing unstable pin.
    fwupd.package = pkgsUnstable.fwupd;
    logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
      IdleAction = "ignore";
    };
  };

  systemd = {
    # Backport the runtime integration required by unstable fwupd 2.1.6.
    # C+ populates the volatile helper directory without deleting signed siblings.
    tmpfiles.rules = [
      "C+ /run/fwupd-efi - - - - ${config.services.fwupd.package.fwupd-efi}/libexec/fwupd/efi"
    ];
    sleep.settings.Sleep = {
      AllowSuspend = false;
      AllowHibernation = false;
      AllowHybridSleep = false;
      AllowSuspendThenHibernate = false;
    };
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
      suspend-then-hibernate.enable = false;
    };
  };

  users.users.roberto = {
    hashedPassword = lib.mkForce null;
    hashedPasswordFile = "/persist/secrets/roberto-password-hash";
  };

  system.stateVersion = "26.05";
}
