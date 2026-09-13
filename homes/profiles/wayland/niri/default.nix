{ pkgs, ... }:
{
  home.packages = [
    pkgs.udiskie
    pkgs.waypipe
    pkgs.wl-clipboard
  ];

  xdg.configFile."niri/config.kdl".text = builtins.readFile ./config.kdl;
}
