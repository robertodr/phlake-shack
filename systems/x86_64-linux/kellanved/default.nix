{
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
{
  imports =
    [
      ./hardware-configuration.nix
      ./disk-config.nix
    ]
    # users
    ++ [
      ../../../users/roberto
    ]
    # base
    ++ map (x: ./../.. + ("/profiles/" + x)) (
      [
        "fonts"
        "hardware/bluetooth"
        "networking"
        "nix"
        "powerManagement"
        "programs/_1password"
        "programs/bash"
        "programs/gnupg"
        "programs/thunar"
        "services/earlyoom"
        "services/flatpak"
        "services/fwupd"
        "services/geoclue2"
        "services/gnome-keyring"
        "services/hardware/bolt"
        #"services/languagetool"
        "services/openssh"
        "services/power-profiles-daemon"
        "services/udisks2"
        "stylix"
        "systemd"
        "zsa"
      ]
      # window manager
      ++ [
        "programs/dconf" # needed?
        "services/blueman"
        "services/dbus" # needed?
        "services/greetd"
        "services/upower"
        "programs/hyprland"
      ]
      # multimedia
      ++ [
        "services/pipewire"
      ]
      # virtualisation
      ++ [
        "virtualisation/docker"
        "virtualisation/virtualbox"
      ]
    );

  boot = {
    kernel = {
      sysctl = {
        # allow perf as user
        "kernel.perf_event_paranoid" = -1;
        "kernel.kptr_restrict" = lib.mkForce 0;
      };
    };

    kernelPackages = pkgs.linuxPackages_latest;

    kernelParams = [ "resume_offset=533760" ];

    resumeDevice = "/dev/disk/by-uuid/625de4d8-3972-4017-b0aa-de227f2cdf03";

    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    # the rollback service is from: https://discourse.nixos.org/t/impermanence-vs-systemd-initrd-w-tpm-unlocking/25167/3
    initrd.systemd.services.root-rollback = {
      description = "Rollback BTRFS root subvolume to a pristine state";
      wantedBy = [
        "initrd.target"
      ];
      after = [
        # LUKS/TPM process
        "systemd-cryptsetup@encrypted.service"
      ];
      before = [
        "sysroot.mount"
      ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /mnt
        # We first mount the btrfs root to /mnt
        # so we can manipulate btrfs subvolumes.
        mount -o subvol=/ /dev/mapper/encrypted /mnt
        # While we're tempted to just delete /root and create
        # a new snapshot from /root-blank, /root is already
        # populated at this point with a number of subvolumes,
        # which makes `btrfs subvolume delete` fail.
        # So, we remove them first.
        #
        # /root contains subvolumes:
        # - /root/var/lib/portables
        # - /root/var/lib/machines
        #
        # I suspect these are related to systemd-nspawn, but
        # since I don't use it I'm not 100% sure.
        # Anyhow, deleting these subvolumes hasn't resulted
        # in any issues so far, except for fairly
        # benign-looking errors from systemd-tmpfiles.
        btrfs subvolume list -o /mnt/root |
          cut -f9 -d' ' |
          while read subvolume; do
            echo "deleting /$subvolume subvolume..."
            btrfs subvolume delete "/mnt/$subvolume"
          done &&
          echo "deleting /root subvolume..." &&
          btrfs subvolume delete /mnt/root
        echo "restoring blank /root subvolume..."
        btrfs subvolume snapshot /mnt/root-blank /mnt/root
        # Once we're done rolling back to a blank snapshot,
        # we can unmount /mnt and continue on the boot process.
        umount /mnt
      '';
    };
  };

  documentation = {
    enable = true;
    man = {
      enable = true;
      generateCaches = true;
    };
    doc.enable = true;
    dev.enable = true;
    info.enable = true;
    nixos.enable = true;
  };

  fileSystems."/persist".neededForBoot = true;

  time.timeZone = lib.mkDefault "Europe/Oslo";
  services.automatic-timezoned.enable = true;

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "it_IT.UTF-8";
    };
  };

  security.polkit.enable = true;

  environment = {
    # impermanence set up
    persistence."/persist" = {
      hideMounts = true;
      directories = [
        "/var/log"
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/fprint"
        "/var/lib/systemd/coredump"
        "/etc/NetworkManager/system-connections"
        {
          directory = "/var/lib/colord";
          user = "colord";
          group = "colord";
          mode = "u=rwx,g=rx,o=";
        }
      ];
      files = [
        {
          file = "/var/keys/secret_file";
          parentDirectory = {
            mode = "u=rwx,g=,o=";
          };
        }
      ];
    };

    # TODO review which packages should be here and which in user profiles
    systemPackages =
      lib.attrVals [
        "acpi" # show battery status and other ACPI information
        "alejandra"
        "atool" # archive command line helper
        "binutils" # tools for manipulating binaries (linker, assembler, etc.)
        "cacert" # a bundle of X.509 certificates of public Certificate Authorities (CA)
        "coreutils" # the basic file, shell and text manipulation utilities of the GNU operating system
        "curl" # a command line tool for transferring files with URL syntax
        "dmidecode" # a tool that reads information about your system's hardware from the BIOS according to the SMBIOS/DMI standard
        "dosfstools" # utilities for creating and checking FAT and VFAT file systems
        "efibootmgr" # a Linux user-space application to modify the Intel Extensible Firmware Interface (EFI) Boot Manager
        "fd"
        "file" # a program that shows the type of files
        "findutils" # GNU Find Utilities, the basic directory searching utilities of the GNU operating system
        "gnupg"
        "gptfdisk" # set of text-mode partitioning tools for Globally Unique Identifier (GUID) Partition Table (GPT) disks
        "libseccomp" # high level library for the Linux Kernel seccomp filter
        "lm_sensors"
        "nix-index"
        "pciutils" # a collection of programs for inspecting and manipulating configuration of PCI devices
        "psmisc" # a set of small useful utilities that use the proc filesystem (such as fuser, killall and pstree)
        "rsync" # a fast incremental file transfer utility
        "sops"
        "ssh-to-age"
        "tree" # command to produce a depth indented directory listing
        "unrar" # utility for RAR archives
        "unzip" # an extraction utility for archives compressed in .zip format
        "usbutils" # tools for working with USB devices, such as lsusb
        "util-linux"
        "wget" # tool for retrieving files using HTTP, HTTPS, and FTP
        "which" # shows the full path of (shell) commands
        "xdg-utils" # a set of command line tools that assist applications with a variety of desktop integration tasks
        "sshfs"
        "zip" # compressor/archiver for creating and modifying zipfiles
      ] pkgs
      ++ [
        pkgsUnstable.neovim
        pkgsUnstable.nixfmt-rfc-style
      ];

    # see here: https://github.com/NixOS/nixpkgs/issues/64965#issuecomment-991839786
    etc."ipsec.secrets".text = ''
      include ipsec.d/ipsec.nm-l2tp.secrets
    '';

    # TODO review these aliases
    shellAliases = {
      # quick cd
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";

      # internet ip
      myip = "${lib.getExe pkgs.dig} +short myip.opendns.com @208.67.222.222 2>&1";
    };
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?
}
