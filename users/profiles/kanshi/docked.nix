{pkgs, ...}: let
  name = "AOC U34G2G4R3 0x00000E8B";
in {
  outputs = [
    {
      criteria = "eDP-1";
      mode = "2256x1504";
      position = "3440,350";
      scale = 1.5;
    }
    {
      criteria = name;
      mode = "3440x1440@144Hz";
      position = "0,0";
      scale = 1.0;
      # can't be set because of this: https://github.com/nix-community/home-manager/issues/3136
      # and this: https://todo.sr.ht/~emersion/kanshi/64
      #adaptive_sync = "on";
    }
  ];

  exec = [
    "${pkgs.sway}/bin/swaymsg workspace number 1, move workspace to '\"${name}\"'"
    "${pkgs.sway}/bin/swaymsg workspace number 2, move workspace to '\"${name}\"'"
    "${pkgs.sway}/bin/swaymsg workspace number 3, move workspace to eDP-1"
    "${pkgs.sway}/bin/swaymsg workspace number 4, move workspace to eDP-1"
  ];
}
