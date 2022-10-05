{
  config,
  lib,
  pkgs,
  suites,
  profiles,
  ...
}: {
  imports =
    [
      # Include the results of the hardware scan.
      # and ZFS partitions configuration
      ./hardware-configuration.nix
      # configuration of kernel and boot due to ZFS
      ./zfs.nix
    ]
    ++ suites.base
    ++ suites.virtualisation
    ++ suites.i3wm
    ++ suites.multimedia
    ++ (with profiles.users; [
      roberto
    ]);

  boot = {
    kernel = {
      sysctl = {
        "kernel.perf_event_paranoid" = 0;
      };
    };
  };

  networking = {
    hostId = "e930e188";
    # hostname is defined by digga
    interfaces = {
      enp0s31f6.useDHCP = lib.mkDefault true;
      wlp4s0.useDHCP = lib.mkDefault true;
    };
  };

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
