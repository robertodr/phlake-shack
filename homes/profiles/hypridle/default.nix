{ ... }:
let
  # avoid starting multiple hyprlock instances
  lock_cmd = "playerctl -a pause; pidof hyprlock || hyprlock";
  display = status: "niri msg action power-${status}-monitors";
in
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        inherit lock_cmd;
        before_sleep_cmd = lock_cmd;
        # to avoid having to press a key twice to turn on the display
        after_sleep_cmd = display "on";
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
          on-timeout = lock_cmd;
        }

        {
          # 6.5min
          timeout = 390;
          # screen off when timeout has passed
          on-timeout = display "off";
          # screen on when activity is detected after timeout has fired
          on-resume = display "on";
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
