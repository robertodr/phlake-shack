{pkgs, ...}: let
  name = "Lenovo Group Limited L32p-30 U5114TM2";
in {
  outputs = [
    {
      criteria = "eDP-1";
      mode = "2256x1504";
      position = "0,850";
      scale = 1.5;
    }
    {
      criteria = name;
      mode = "3840x2160";
      position = "1504,0";
      scale = 1.5;
    }
  ];

  exec = [
    "${pkgs.sway}/bin/swaymsg workspace number 1, move workspace to '\"${name}\"'"
    "${pkgs.sway}/bin/swaymsg workspace number 2, move workspace to '\"${name}\"'"
    "${pkgs.sway}/bin/swaymsg workspace number 3, move workspace to eDP-1"
    "${pkgs.sway}/bin/swaymsg workspace number 4, move workspace to eDP-1"
  ];
}
