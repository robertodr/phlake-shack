{pkgs, ...}: {
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    terminal = "kitty";
    font = "M PLUS 2 Regular 14";
    theme = "arthur";
    extraConfig = {
      modi = "window,windowcd,ssh,drun,combi,filebrowser";
    };
  };
}
