{
  pkgs,
  ...
}:
{
  home = {
    packages = [
      pkgs.waypipe
      pkgs.wl-clipboard
    ];
  };

  xdg.configFile."niri/config.kdl".source = ./config.kdl;
}
