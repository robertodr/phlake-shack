{pkgs, ...}: let
  name = "Lenovo Group Limited E27q-20 V5HNR679";
in {
  outputs = [
    {
      criteria = "eDP-1";
      mode = "2256x1504";
      position = "530,1440";
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
