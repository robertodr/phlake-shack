{pkgs, ...}: let
  name = "Dell Inc. DELL C2722DE F4FNZG3";
in {
  outputs = [
    {
      criteria = "eDP-1";
      mode = "2256x1504";
      position = "2560,260";
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
