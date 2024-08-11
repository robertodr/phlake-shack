{
  lib,
  pkgs,
  ...
}: let
  sup = "Mod1"; # this is the "Alt" key
  mod = "Mod4"; # this is the "Windows" key

  # commands to be run on each startup
  alwaysRun = [
  ];

  lockCmd = "\'${pkgs.playerctl}/bin/playerctl -a pause; ${pkgs.hyprlock}/bin/hyprlock\'";

  commandLineArgs = toString [
    "--enable-features=UseOzonePlatform,WaylandWindowDecorations"
    "--ozone-platform=wayland"
  ];

  # commands to be run on sway startup
  # TODO probably add 1password GUI as well?
  run = [
    #"wezterm"
    "kitty"
    "firefox"
    "ferdium ${commandLineArgs}"
    "thunderbird"
    #"joplin-desktop ${commandLineArgs}"
  ];
in {
  home.packages = with pkgs; [
    wl-clipboard
  ];

  wayland = {
    windowManager = {
      hyprland = {
        enable = true;

        systemd = {
          enable = true;
          enableXdgAutostart = true;
        };

        settings = {
          "$mod" = "SUPER";
          bind =
            [
              "$mod, F, exec, firefox"
              ", Print, exec, grimblast copy area"
            ]
            ++ (
              # workspaces
              # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
              builtins.concatLists (builtins.genList (
                  x: let
                    ws = let
                      c = (x + 1) / 10;
                    in
                      builtins.toString (x + 1 - (c * 10));
                  in [
                    "$mod, ${ws}, workspace, ${toString (x + 1)}"
                    "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
                  ]
                )
                10)
            );
        };
      };
    };
  };
}
