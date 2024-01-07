{pkgs, ...}: let
  name = "Hewlett Packard HP ZR2740w CNT312Y0FK";
in {
  outputs = [
    {
      criteria = "eDP-1";
      mode = "2256x1504";
      position = "540,1440";
      scale = 1.5;
    }
    {
      criteria = name;
      mode = "2560x1440";
      position = "0,0";
      scale = 1.0;
    }
  ];

  exec = [
    "${pkgs.sway}/bin/swaymsg workspace number 1, move workspace to '\"${name}\"'"
    "${pkgs.sway}/bin/swaymsg workspace number 2, move workspace to '\"${name}\"'"
    "${pkgs.sway}/bin/swaymsg workspace number 3, move workspace to eDP-1"
    "${pkgs.sway}/bin/swaymsg workspace number 4, move workspace to eDP-1"
  ];
}
