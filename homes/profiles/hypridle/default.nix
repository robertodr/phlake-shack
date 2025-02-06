{lib, ...}:
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # avoid starting multiple hyprlock instances
        lock_cmd = "pidof hyprlock || hyprlock";
        # to avoid having to press a key twice to turn on the display
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        {
          # 5min
          timeout = 300;
          # set monitor backlight to minimum, avoid 0 on OLED monitor
          on-timeout = "brightnessctl -s set 10";
          # monitor backlight restore
          on-resume = "brightnessctl -r";
        }

        # turn off keyboard backlight, comment out this section if you don't have a keyboard backlight
        {
          # 5min
          timeout = 300;
          # turn off keyboard backlight
          on-timeout = "brightnessctl -sd '*::kbd_backlight' set 0";
          # turn on keyboard backlight
          on-resume = "brightnessctl -rd '*::kbd_backlight'";
        }

        {
          # 6min
          timeout = 360;
          # lock screen when timeout has passed
          on-timeout = "playerctl -a pause && loginctl lock-session";
        }

        {
          # 6.5min
          timeout = 390;
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

  # as per: https://github.com/nix-community/home-manager/issues/5899#issuecomment-2498226238
  systemd.user.services.hypridle.Unit.After = lib.mkForce "graphical-session.target";
}
