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
      "powerManagement/tuning"
      "programs/_1password"
      "programs/bash"
      "programs/gnupg"
      "programs/nix-ld"
      "programs/thunar"
      "services/fwupd"
      "services/geoclue2"
      "services/hardware/bolt"
      "services/oomd"
      "services/openssh"
      "services/tuned"
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
      "programs/niri"
    ]
    # multimedia
    ++ [
      "services/pipewire"
    ]
    # virtualisation
    ++ [
      "virtualisation/docker"
    ]
  );

  # Temporary workaround for timed wakes being mistaken for manual wakes.
  # https://github.com/systemd/systemd/issues/38193
  # Remove this override once upstream fixes the timer-readiness race.
  systemd.package = pkgs.systemd.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/systemd-sleep-timer-grace.patch ];
  });

  boot = {
    kernel = {
      sysctl = {
        # allow perf as user
        "kernel.perf_event_paranoid" = -1;
        "kernel.kptr_restrict" = lib.mkForce 0;
      };
    };

    kernelPackages = pkgs.linuxPackages_latest;

    kernelParams = [
      "quiet"
      "splash"
      "intremap=on"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
      "resume_offset=533760"
      # Adaptive backlight modulation. The panel backlight is the largest
      # single consumer in the powertop report (26.6% utilisation). Levels are
      # 0-4; ABM dims the backlight and compensates in the pixel data, so
      # higher levels are increasingly visible on gradients and unsuitable for
      # colour-critical work. Drop to 1 or remove if the shifts are noticeable.
      "amdgpu.abmlevel=2"
      # Do NOT re-enable panel self refresh here. nixos-hardware's
      # framework-13-7040-amd module passes amdgpu.dcdebugmask=0x10
      # (DC_DISABLE_PSR); leave it alone. Overriding it with a mkAfter
      # "amdgpu.dcdebugmask=0x0" was tried on 2026-08-18 and hard-hung the
      # display twice in two days: DMCUB faults, then endless
      # "[CRTC:369:crtc-0] flip_done timed out", so niri can never present
      # another frame. The machine keeps running and stays reachable over ssh,
      # but the screen is dead until a power-button reset. Both hangs began
      # after a long static-screen idle, which is exactly when PSR engages.
      #
      # If it ever seems worth retrying, amdgpu.dcdebugmask=0x200
      # (DC_DISABLE_PSR_SU) keeps PSR1 while disabling selective update, where
      # most of the DMCUB bugs live. Note dcdebugmask is read-only at runtime,
      # so any such experiment costs a rebuild and a reboot to test.
    ];

    resumeDevice = "/dev/disk/by-uuid/625de4d8-3972-4017-b0aa-de227f2cdf03";

    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    initrd = {
      verbose = false;
      systemd = {
        # CRITICAL: Required for pam_fde_boot_pw to work
        # Stores the LUKS password in systemd so it can be retrieved later
        enable = true;
        # the rollback service is from: https://discourse.nixos.org/t/impermanence-vs-systemd-initrd-w-tpm-unlocking/25167/3
        services.root-roolback = {
          description = "Rollback BTRFS root subvolume to a pristine state";
          wantedBy = [
            "initrd.target"
          ];
          after = [
            # LUKS/TPM process
            "systemd-cryptsetup@encrypted.service"
            # Now that suspend-then-hibernate is in use, the rollback must not
            # get a chance to run on a resume boot: the resumed image's page
            # cache still refers to the /root subvolume this service deletes.
            # There is no explicit ordering otherwise, so it is a race. Placing
            # the rollback after the resume attempt settles it, because a
            # successful resume never returns to the initrd, while an ordinary
            # boot has systemd-hibernate-resume exit immediately.
            "systemd-hibernate-resume.service"
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
    };

    plymouth = {
      enable = true;
      font = "${pkgs.mplus-outline-fonts.githubRelease}/share/fonts/truetype/mplus-outline-fonts/Mplus2-Bold.ttf";
      logo = "${pkgs.nixos-icons}/share/icons/hicolor/128x128/apps/nix-snowflake.png";
      theme = "unrap";
      themePackages = [
        (
          (pkgs.adi1090x-plymouth-themes.overrideAttrs (oldAttrs: {
            installPhase = (oldAttrs.installPhase or "") + ''
              for theme in ${config.boot.plymouth.theme}; do
                echo 'nixos_image = Image("header-image.png");' >> $out/share/plymouth/themes/$theme/$theme.script
                echo 'nixos_sprite = Sprite();' >> $out/share/plymouth/themes/$theme/$theme.script
                echo 'nixos_sprite.SetImage(nixos_image);' >> $out/share/plymouth/themes/$theme/$theme.script
                echo 'nixos_sprite.SetX(Window.GetX() + (Window.GetWidth() / 2 - nixos_image.GetWidth() / 2));' >> $out/share/plymouth/themes/$theme/$theme.script
                echo 'nixos_sprite.SetY(Window.GetHeight() - nixos_image.GetHeight() - 50);' >> $out/share/plymouth/themes/$theme/$theme.script
              done
            '';
          })).override
            { selected_themes = [ config.boot.plymouth.theme ]; }
        )
        (pkgs.runCommand "add-logos" { inherit (config.boot.plymouth) logo theme; } ''
          mkdir -p $out/share/plymouth/themes/$theme
          ln -s $logo $out/share/plymouth/themes/$theme/header-image.png
        '')
      ];
    };
  };

  documentation = {
    enable = true;
    man = {
      enable = true;
      cache.enable = true;
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

  programs.ssh.knownHosts = {
    "sshca.my-eurohpc.eu".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlPFxv2xhvg2Jlyt7TE8cTuVbk27LpFJmILWpXm/7xz";
  };

  # Noctalia drives fprintd directly. Keep fingerprint out of its password PAM
  # transaction so password submission reaches pam_unix immediately. Fingerprint
  # authentication for sudo remains unchanged; text-console login does not need it.
  security.pam.services.login.fprintAuth = false;

  security.polkit = {
    enable = true;
    debug = true;
  };

  sops = {
    age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      "ibm-cloud/token" = {
        sopsFile = ../../../secrets/ibm-cloud.yaml;
        owner = config.users.users.roberto.name;
      };
      "kenn-forge/env" = {
        sopsFile = ../../../secrets/kenn-forge.env;
        format = "dotenv";
        owner = config.users.users.roberto.name;
      };
    };
  };

  environment = {
    # impermanence set up
    persistence."/persist" = {
      hideMounts = true;
      directories = [
        "/etc/NetworkManager/system-connections"
        "/var/lib/bluetooth"
        "/var/lib/docker"
        "/var/lib/fprint"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/var/lib/systemd/timers"
        "/var/log"
        {
          directory = "/var/lib/colord";
          user = "colord";
          group = "colord";
          mode = "u=rwx,g=rx,o=";
        }
      ];
      files = [
        "/etc/machine-id"
        {
          file = "/var/keys/secret_file";
          parentDirectory = {
            mode = "u=rwx,g=,o=";
          };
        }
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };

    # TODO review which packages should be here and which in user profiles
    systemPackages =
      lib.attrVals [
        "acpi" # show battery status and other ACPI information
        "age"
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
      ];
  };

  system = {
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
    stateVersion = "24.11"; # Did you read the comment?
  };
}
