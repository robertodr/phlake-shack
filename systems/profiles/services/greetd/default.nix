{
  lib,
  config,
  pkgs,
  ...
}: let
  hyprland = lib.getExe' config.programs.hyprland.package "Hyprland";
  hyprctl = lib.getExe' config.programs.hyprland.package "hyprctl";
  regreet = lib.getExe config.programs.regreet.package;
  greetdHyprlandConfig = pkgs.writeText "greetd-hyprland-config" ''
    debug {
      disable_logs=false
      disable_time=false
    }

    animations {
      enabled=false
      first_launch_animation=false
    }

    misc {
      disable_hyprland_logo=true
      disable_splash_rendering=true
    }

    exec-once = ${regreet}; ${hyprctl} dispatch exit
  '';
in {
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal"; # without this errors will spam on screen
    TTYReset = true; # without these bootlogs will spam on screen
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${hyprland} --config ${greetdHyprlandConfig}";
        user = "roberto";
      };
    };
  };

  security.pam.services.greetd = {
    enableGnomeKeyring = true;
    gnupg.enable = true;
  };

  programs.regreet = {
    enable = true;
    settings = {
      background = {
        path = config.stylix.image;
        fit = "Cover";
      };
      GTK = {
        cursor_theme_name = config.stylix.cursor.name;
        font_name = config.stylix.fonts.sansSerif.name;
        icon_theme_name = "Nordzy-dark";
      };
    };
  };
}
