{
  config,
  lib,
  pkgs,
  ...
}: let
  hyprlock = lib.getExe config.programs.hyprlock.package;
  brightnessctl = lib.getExe pkgs.brightnessctl;
  playerctl = lib.getExe config.services.playerctld.package;
in {
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # avoid starting multiple hyprlock instances
        lock_cmd = "pidof hyprlock || ${hyprlock}";
        # lock before suspend
        before_sleep_cmd = "loginctl lock-session";
        # to avoid having to press a key twice to turn on the display
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        {
          # 2.5min
          timeout = 150;
          # set monitor backlight to minimum, avoid 0 on OLED monitor
          on-timeout = "${brightnessctl} -s set 10";
          # monitor backlight restore
          on-resume = "${brightnessctl} -r";
        }

        # turn off keyboard backlight, comment out this section if you don't have a keyboard backlight
        {
          # 2.5min
          timeout = 150;
          # turn off keyboard backlight
          on-timeout = "${brightnessctl} -sd '*::kbd_backlight' set 0";
          # turn on keyboard backlight
          on-resume = "${brightnessctl} -rd '*::kbd_backlight'";
        }

        {
          # 3min
          timeout = 180;
          # lock screen when timeout has passed
          on-timeout = "${playerctl} -a pause && loginctl lock-session";
        }

        {
          # 3.5min
          timeout = 210;
          # screen off when timeout has passed
          on-timeout = "hyprctl dispatch dpms off";
          # screen on when activity is detected after timeout has fired
          on-resume = "hyprctl dispatch dpms on";
        }

        {
          # 1hour
          timeout = 3600;
          # suspend pc
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
