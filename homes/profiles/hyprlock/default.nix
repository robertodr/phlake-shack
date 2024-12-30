{
  pkgs,
  config,
  ...
}: let
  wallpaper = pkgs.fetchurl {
    url = "https://w.wallhaven.cc/full/85/wallhaven-856e2j.jpg";
    sha256 = "01bkswh8zb4v7ljkzbnn05qdmk9cxxbmryczilc3v8fhbchr094p";
  };
in {
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        no_fade_in = true;
        no_fade_out = true;
      };

      background = [
        {
          monitor = "";
          path = "${wallpaper}";
          blur_passes = 0;
          blur_size = 2;
          noise = 0.1;
          contrast = 0.7;
          brightness = 0.6;
          vibrancy = 0.1;
          vibrancy_darkness = 0.0;
        }
      ];

      label = [
        # Hours
        {
          monitor = "";
          text = "cmd[update:1000] echo \"<b><big> \"$(date +'%H')\" </big></b>\"";
          color = "rgb(${config.lib.stylix.colors.base00})";
          font_size = 112;
          font_family = "${config.stylix.fonts.sansSerif.name}";
          shadow_passes = 3;
          shadow_size = 4;
          position = "0, 220";
          halign = "center";
          valign = "center";
        }

        # Minutes
        {
          monitor = "";
          text = "cmd[update:1000] echo \"<b><big> \"$(date +'%M')\" </big></b>\"";
          color = "rgb(${config.lib.stylix.colors.base00})";
          font_size = 112;
          font_family = "${config.stylix.fonts.sansSerif.name}";
          shadow_passes = 3;
          shadow_size = 4;
          position = "0, 80";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "250, 50";
          outline_thickness = 3;
          dots_size = 0.33; # Scale of input-field height, 0.2 - 0.8
          dots_spacing = 0.15; # Scale of dots' absolute size, 0.0 - 1.0
          dots_center = true;
          dots_rounding = -1; # -1 default circle, -2 follow input-field rounding
          outer_color = "rgb(${config.lib.stylix.colors.base00})";
          inner_color = "rgb(${config.lib.stylix.colors.base00})";
          font_color = "rgb(${config.lib.stylix.colors.base0A})";
          fade_on_empty = true;
          fade_timeout = 1000; # Milliseconds before fade_on_empty is triggered.
          placeholder_text = "<i>Input Password...</i>"; # Text rendered in the input box when it's empty.
          hide_input = false;
          rounding = -1; # -1 means complete rounding (circle/oval)
          check_color = "rgb(${config.lib.stylix.colors.base0B})";
          fail_color = "rgb(${config.lib.stylix.colors.base08})"; # if authentication failed, changes outer_color and fail message color
          fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>"; # can be set to empty
          fail_transition = 300; # transition time in ms between normal outer_color and fail_color
          capslock_color = -1;
          numlock_color = -1;
          bothlock_color = -1; # when both locks are active. -1 means don't change outer color (same for above)
          invert_numlock = false; # change color if numlock is off
          swap_font_color = false; # see below
          position = "0, -180";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
