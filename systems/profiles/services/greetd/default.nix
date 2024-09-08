{
  lib,
  config,
  ...
}: {
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
        command = "${lib.getExe' config.programs.hyprland.package "Hyprland"}";
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

  environment.etc = {
    "greetd/environments".text = ''
      Hyprland
    '';
  };
}
