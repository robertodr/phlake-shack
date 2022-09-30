{ config, lib, pkgs, suites, profiles, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ]
  ++ suites.base
  ++ suites.i3
  ++ suites.multimedia
  ++ suites.virtualisation
  ++ (with profiles.users; [
    roberto
  ])
  ;

  boot = {
    kernel = {
      sysctl = {
        "kernel.perf_event_paranoid" = 0;
      };
    };

    kernelPackages = pkgs.linuxPackages_latest;

    # Bootloader.
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/efi";
      };
    };

    initrd = {
      # Setup keyfile
      secrets = {
        "/crypto_keyfile.bin" = null;
      };

      # Enable swap on luks
      luks.devices."luks-86b15b19-f5c3-4b0f-97f1-5e1ba08fcc6b".device = "/dev/disk/by-uuid/86b15b19-f5c3-4b0f-97f1-5e1ba08fcc6b";
      luks.devices."luks-86b15b19-f5c3-4b0f-97f1-5e1ba08fcc6b".keyFile = "/crypto_keyfile.bin";
    };
  };

  networking = {
    # hostname is defined by digga
    interfaces = {
      wlp166s0.useDHCP = lib.mkDefault true;
    };
  };

  # NOTE fprintd is enabled by default on the Framework!
  services.fprintd.enable = false;

  system = {
    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    stateVersion = "22.05";
  };
}
