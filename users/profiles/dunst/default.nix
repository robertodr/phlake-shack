{pkgs, ...}: {
  services.dunst = {
    enable = false;
    iconTheme = {
      name = "ePapirus";
      package = pkgs.papirus-icon-theme;
      size = "16x16";
    };
    settings = {
      global = {
        corner_radius = 16;
        follow = "mouse";
        font = "M PLUS 2 Regular 14";
        # escape \n with \
        format = "<b>%s</b>\\n%b";
        frame_color = "#b16286";
        frame_width = 8;
        geometry = "1000x10-40+160";
        horizontal_padding = 8;
        icon_position = "off";
        ignore_newlines = false;
        markup = "full";
        padding = 8;
        show_indicators = false;
        shrink = false;
        word_wrap = true;
      };
      urgency_critical = {
        background = "#3c3836";
        foreground = "#ebdbb2";
        timeout = 10;
      };
      urgency_low = {
        background = "#3c3836";
        foreground = "#ebdbb2";
        timeout = 10;
      };
      urgency_normal = {
        background = "#3c3836";
        foreground = "#ebdbb2";
        timeout = 10;
      };
    };
  };
}
