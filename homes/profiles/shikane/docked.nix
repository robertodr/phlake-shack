{
  lib,
  pkgs,
  ...
}: {
  name = "docked";
  exec = [
    "${lib.getExe pkgs.libnotify} shikane \"Profile $SHIKANE_PROFILE_NAME has been applied\""
    # let hyprland know the relative positioning of the screens
    # TODO figure out whether it's needed in future releases
    #hyprctl keyword monitor eDP-1, 2256x1504@60, 3440x350, 1.6"
    #hyprctl keyword monitor desc:AOC U34G2G4R3 0x00000E8B, 3440x1440@120, 0x0, 1, vrr, 1"
    # TODO needs some JSON parsing to use hyprctl like so:
    # hyprctl keyword workspace "$i, monitor:${monitors[0]}" > /dev/null
    # hyprctl dispatch moveworkspacetomonitor $i ${monitors[0]} > /dev/null
    #  "${pkgs.sway}/bin/swaymsg workspace number 1, move workspace to '\"${name}\"'"
    #  "${pkgs.sway}/bin/swaymsg workspace number 2, move workspace to '\"${name}\"'"
    #  "${pkgs.sway}/bin/swaymsg workspace number 3, move workspace to eDP-1"
    #  "${pkgs.sway}/bin/swaymsg workspace number 4, move workspace to eDP-1"
  ];
  output = [
    {
      search = "eDP-1";
      enable = true;
      mode = "2256x1504@60Hz";
      position = "3440,350";
      scale = 1.6;
    }
    {
      search = "%AOC U34G2G4R3 0x00000E8B";
      enable = true;
      mode = "3440x1440@60Hz";
      position = "0,0";
      scale = 1.0;
      adaptive_sync = true;
    }
  ];
}
