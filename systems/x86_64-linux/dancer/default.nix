{ lib, ... }:
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
    logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
      IdleAction = "ignore";
    };
  };

  systemd = {
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
