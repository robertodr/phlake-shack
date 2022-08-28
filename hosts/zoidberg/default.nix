{ config, lib, pkgs, suites, profiles, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    # also includes additional ZFS stuff, maybe move it?
    ./hardware-configuration.nix
  ]
  ++ suites.base
  ++ suites.development
  ++ suites.virtualization
  ++ suites.thinkpad
  ++ suites.i3
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

    loader = {
      # Use the systemd-boot EFI boot loader.
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # parameter added because of this: https://nixos.wiki/wiki/ZFS#Known_issues
    kernelParams = [ "nohibernate" ];
    supportedFilesystems = [ "zfs" ];
    zfs.devNodes = "/dev/";
  };

  # ZFS maintenance settings.
  services.zfs = {
    trim.enable = true;
    autoScrub = {
      enable = true;
      pools = [ "rpool" ];
    };
  };

  networking = {
    hostId = "f3780fae";
    # hostname is defined by digga
    interfaces = {
      enp0s31f6.useDHCP = lib.mkDefault true;
      wlp4s0.useDHCP = lib.mkDefault true;
    };
  };

  system = {
    # Copy the NixOS configuration file and link it from the resulting system
    # (/run/current-system/configuration.nix). This is useful in case you
    # accidentally delete configuration.nix.
    copySystemConfiguration = true;

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    stateVersion = "22.05";
  };
}
