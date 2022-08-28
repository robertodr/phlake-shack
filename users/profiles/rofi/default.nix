{ ... }:

{
  programs.rofi = {
    enable = true;
    terminal = "kitty";
    font = "M PLUS 2 Regular 14";
    theme = "arthur";
    extraConfig = {
      modi = "window,windowcd,ssh,drun,combi,filebrowser";
    };
  };
}
