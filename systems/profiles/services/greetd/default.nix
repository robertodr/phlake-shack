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

  services.greetd = let
    session = {
      command = "${lib.getExe config.programs.uwsm.package} start hyprland-uwsm.desktop";
      user = "roberto";
    };
  in {
    enable = true;
    settings = {
      terminal.vt = 1;
      default_session = session;
      initial_session = session;
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
    };
  };
}
