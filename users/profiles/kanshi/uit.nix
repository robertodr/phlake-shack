{pkgs, ...}: let
  name = "Samsung Electric Company C34H89x H4ZR909034";
in {
  outputs = [
    {
      criteria = "eDP-1";
      mode = "2256x1504";
      position = "2477,1440";
      scale = 1.5;
    }
    {
      criteria = name;
      mode = "3440x1440";
      position = "1504,0";
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
