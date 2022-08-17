{ pkgs, ... }:

{
  services.polybar = {
    enable = true;
    package = pkgs.polybar.override {
      alsaSupport = true;
      i3GapsSupport = true;
      iwSupport = true;
      nlSupport = true;
      pulseSupport = true;
    };
    # based on https://github.com/kiddae/polybar-themes/blob/master/blocks/config
    settings = {
      "colors" = {
        # use https://github.com/joshyrobot/base16-material-vivid-scheme
        background = "#202124";
        color1 = "#323639";
        color2 = "#676c71";
        color3 = "#9e9e9e";
      };

      "bar/base" = {
        font-0 = "M PLUS 2:style=Regular:size=11:antialias=true;3";
        font-1 = "Material Icons:style=Regular:size=9:antialias=true;3";
        font-2 = "FontAwesome:style=Regular:size=9:antialias=true;3";
        font-3 = "github\-octicons:style=Regular:size=9:antialias=true;3";
        height = 45;
        background = "\${colors.background}";
        override-redirect = true;
        offset-y = 5;
        wm-restack = "i3";
      };

      "bar/i3" = {
        "inherit" = "bar/base";
        width = "25%";
        foreground = "\${colors.color1}";
        offset-x = 10;
        modules-left = "i3 xwindow";
        scroll-up = "#i3.prev";
        scroll-down = "#i3.next";
      };

      "module/i3" = {
        type = "internal/i3";
        format = "<label-state> <label-mode>";
        format-padding = 1;
        format-background = "\${colors.color1}";
        format-foreground = "\${colors.background}";
        index-sort = true;
        wrapping-scroll = false;
        enable-click = true;
        reverse-scroll = false;
        label-focused = "%icon%";
        label-focused-font = 3;
        label-focused-foreground = "\${colors.background}";
        label-focused-padding = 1;
        label-unfocused = "%index%";
        label-unfocused-font = 2;
        label-unfocused-padding = 1;
        label-unfocused-foreground = "\${colors.background}";
        label-visible = "%index%";
        label-visible-underline = "\${colors.background}";
        label-visible-padding = 1;
        label-urgent = "%index%";
        label-urgent-font = 1;
        label-urgent-padding = 1;
        label-urgent-foreground = "\${colors.background}";
        ws-icon-0 = "1;♚";
        ws-icon-1 = "2;♛";
        ws-icon-2 = "3;♜";
        ws-icon-3 = "4;♝";
        ws-icon-4 = "5;♞";
        ws-icon-default = "♟";
      };

      "module/xwindow" = {
        type = "internal/xwindow";
        label = "%title:0:50:...%";
        label-foreground = "\${colors.color1}";
        label-background = "\${colors.background}";
        label-padding = 2;
      };

      "bar/music" = {
        "inherit" = "bar/base";
        enable-ipc = true;
        width = "28%";
        foreground = "\${colors.color2}";
        offset-x = "25.5%";
        modules-left = "previous playpause next spotify";
      };

      "module/previous" = {
        type = "custom/script";
        format-font = 3;
        format-padding = 2;
        format-background = "\${colors.color2}";
        format-foreground = "\${colors.background}";
        exec = "echo \"  \"";
        exec-if = "pgrep spotify";
        click-left = "playerctl previous";
      };

      "module/next" = {
        type = "custom/script";
        format-font = 3;
        format-padding = 2;
        format-background = "\${colors.color2}";
        format-foreground = "\${colors.background}";
        exec = "echo \"  \"";
        exec-if = "pgrep spotify";
        click-left = "playerctl next";
      };

      "module/playpause" = {
        type = "custom/script";
        exec = "spotifystatus";
        exec-if = "pgrep spotify";
        format-font = 3;
        format-background = "\${colors.color2}";
        format-foreground = "\${colors.background}";
        format-padding = 1;
        tail = true;
        interval = 0;
        click-left = "playerctl -p spotify play-pause";
      };

      "module/spotify" = {
        type = "custom/script";
        exec = "playerctl -p spotify metadata --format '{{artist}}: {{title}}'";
        exec-if = "pgrep spotify";
        format-padding = 2;
        tail = true;
        interval = 1;
      };

      "bar/tray" = {
        "inherit" = "bar/base";
        width = "35%";
        padding-right = 0;
        offset-x = "60%";
        modules-left = "xkeyboard time battery";
        # position of the system tray
        tray-position = "right";
      };

      "module/xkeyboard" = {
        type = "internal/xkeyboard";
      };

      "module/time" =
        {
          type = "internal/date";
          date = "%A, %B %d %Y";
          time = "%H:%M";
          label = "%time% - %date%";
          format = "<label>";
          label-padding = 2;
          label-foreground = "\${colors.background}";
          label-background = "\${colors.color3}";
        };

      "module/battery" = {
        type = "internal/battery";
        battery = "BAT0";
        adapter = "ADP1";
        format-charging = "<label-charging> <bar-capacity>";
        format-discharging = "<label-discharging> <bar-capacity>";
        padding = 5;
        label-charging = "%percentage%%";
        label-discharging = "%percentage%%";
        bar-capacity-width = 5;
        bar-capacity-format = "%{+u}%{+o}%fill%%empty%%{-u}%{-o}";
        bar-capacity-fill = "█";
        bar-capacity-fill-foreground = "\${colors.color3}";
        bar-capacity-fill-font = 3;
        bar-capacity-empty = "█";
        bar-capacity-empty-font = 3;
        bar-capacity-empty-foreground = "\${colors.color1}";
      };

      "settings" = {
        screenchange-reload = true;
        tray-padding = 0;
        tray-background = "\${colors.background}";
        tray-detached = false;
        tray-maxsize = 6;
        tray-offset-x = 0;
        tray-offset-y = 0;
        tray-scale = 1.0;
      };

      "global/wm" = {
        margin-top = 0;
        margin-bottom = 0;
      };
    };

    script = ''
      polybar tray &
      #polybar music &
      polybar i3 &
    '';
  };
}
