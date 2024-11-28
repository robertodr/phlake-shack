# FIXME I would like to split each configuration to its own file (like I had it with Kanshi)
{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  package = pkgsUnstable.shikane;
  tomlFormat = pkgs.formats.toml {};
  hyprctl = lib.getExe' config.wayland.windowManager.hyprland.package "hyprctl";

  settings = {
    profile = [
      {
        name = "undocked";
        exec = [
          "${lib.getExe pkgs.libnotify} shikane \"Profile $SHIKANE_PROFILE_NAME has been applied\""
        ];
        output = [
          {
            enable = true;
            search = "eDP-1";
            position = "0,0";
            mode = "2256x1504@60Hz";
            scale = 1.175;
          }
        ];
      }
      {
        name = "docked";
        exec = [
          "${lib.getExe pkgs.libnotify} shikane \"Profile $SHIKANE_PROFILE_NAME has been applied\""
          # let hyprland know the relative positioning of the screens
          # TODO figure out whether it's needed in future releases
          #"${hyprctl} keyword monitor eDP-1, 2256x1504@60, 3440x350, 1.6"
          #"${hyprctl} keyword monitor desc:AOC U34G2G4R3 0x00000E8B, 3440x1440@120, 0x0, 1, vrr, 1"
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
      {
        name = "uio";
        exec = [
          "${lib.getExe pkgs.libnotify} shikane \"Profile $SHIKANE_PROFILE_NAME has been applied\""
        ];
        output = [
          {
            search = "eDP-1";
            enable = true;
            mode = "2256x1504@60Hz";
            position = "344,1440";
            scale = 1.6;
          }
          {
            search = "%Dell Inc. DELL U2720Q HR5GZ13";
            enable = true;
            mode = "3840x2160@60Hz";
            position = "0,0";
            scale = 1.5;
            adaptive_sync = true;
          }
        ];
      }
    ];
  };
in {
  home.packages = [
    pkgs.wdisplays
    pkgsUnstable.shikane
  ];

  systemd.user.services.shikane = {
    Unit = {
      Description = "Dynamic output configuration tool";
      Documentation = "man:shikane(1)";
      After = ["graphical-session-pre.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      ExecStart =
        lib.escapeShellArgs [(lib.getExe package) "--config" (tomlFormat.generate "shikane-config" settings)];
    };

    Install = {WantedBy = ["graphical-session.target"];};
  };
}
