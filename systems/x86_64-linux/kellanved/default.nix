{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../../users/roberto
    ../../profiles/base
    ../../profiles/development
    ../../profiles/desktop
    ../../profiles/impermanence
    ../../profiles/powerManagement
    ../../profiles/powerManagement/tuning
    ../../profiles/services/openssh
    ../../profiles/services/tuned
  ];

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

  networking.hostName = "kellanved";

  programs.ssh.knownHosts = {
    "sshca.my-eurohpc.eu".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlPFxv2xhvg2Jlyt7TE8cTuVbk27LpFJmILWpXm/7xz";
  };

  environment.persistence."/persist".directories = lib.mkMerge [
    [
      "/var/lib/bluetooth"
    ]
    (lib.mkAfter [
      "/var/lib/fprint"
    ])
    (lib.mkOrder 1600 [
      {
        directory = "/var/lib/colord";
        user = "colord";
        group = "colord";
        mode = "u=rwx,g=rx,o=";
      }
    ])
  ];

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
