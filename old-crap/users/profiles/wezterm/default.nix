{pkgs, ...}: {
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      return {
        font = wezterm.font("Fira Code Nerd Font"),
        font_size = 14.0,
        color_scheme = "Blue Matrix",
        -- color_scheme = "Belge (terminal.sexy)",
        hide_tab_bar_if_only_one_tab = true,
        enable_kitty_keyboard = true
      }
    '';
  };
}
