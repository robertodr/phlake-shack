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
  ++ (with profiles.users; [
    roberto
  ])
  ;

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader = {
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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = {
  #   "eurosign:e";
  #   "caps:escape" # map caps to escape.
  # };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?
}
