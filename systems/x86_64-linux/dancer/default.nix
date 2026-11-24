{
  config,
  lib,
  pkgs,
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
    ../../profiles/services/openssh/lan-and-tailscale.nix
    ../../profiles/services/tailscale/dancer-ssh.nix
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

  # Secret Service for GitButler's GitHub credentials. This also enables
  # PAM unlocking for console password logins; SSH key logins need manual unlock.
  services.gnome.gnome-keyring.enable = true;
  environment.systemPackages = [ pkgs.libsecret ];

  # GNOME Keyring 50.0 creates the login keyring via its control socket but
  # does not export the new collection until the daemon restarts. Backport
  # the upstream registration fix so setup never has to restart the daemon.
  nixpkgs.overlays = [
    (final: prev: {
      gnome-keyring = prev.gnome-keyring.overrideAttrs (old: {
        patches =
          (old.patches or [ ])
          ++ lib.optionals (old.version == "50.0") [
            (final.fetchurl {
              url = "https://github.com/GNOME/gnome-keyring/commit/8fb9c2a6325af1908facefbb03178194157ac2da.patch";
              hash = "sha256-St9mXnKkVa1KBMzBLtFRI86OxoHLSCs65csHycN0z1s=";
            })
          ];
      });
    })
  ];

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
