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
      ./hardware-configuration.nix
    ]
    ++ suites.base
    ++ suites.swaywm
    ++ suites.multimedia
    ++ suites.virtualisation
    ++ (with profiles.users; [
      roberto
    ]);

  boot = {
    kernel = {
      sysctl = {
        "kernel.perf_event_paranoid" = 0;
      };
    };

    kernelPackages = pkgs.linuxPackages_latest;

    # make some extra kernel modules available to NixOS
    extraModulePackages = [
      config.boot.kernelPackages.v4l2loopback.out
    ];

    # activate kernel modules (choose from built-ins and extra ones)
    kernelModules = [
      # Virtual Camera
      "v4l2loopback"
      # Virtual Microphone, built-in
      "snd-aloop"
    ];

    # initial kernel module settings
    extraModprobeConfig = ''
      # exclusive_caps: Skype, Zoom, Teams etc. will only show device when actually streaming
      # card_label: Name of virtual camera, how it'll show up in Skype, Zoom, Teams
      # https://github.com/umlaeute/v4l2loopback
      options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
    '';

    # bootloader
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

  services.tlp = {
    enable = true;
    settings = {
      CPU_BOOST_ON_BAT = 0;
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BATTERY = "powersave";
      START_CHARGE_THRESH_BAT0 = 90;
      STOP_CHARGE_THRESH_BAT0 = 97;
      RUNTIME_PM_ON_BAT = "auto";
      PCIE_ASPM_ON_BAT = "powersupersave";
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
