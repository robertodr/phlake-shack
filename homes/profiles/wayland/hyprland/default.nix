{
  config,
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

  brightnessctl = lib.getExe pkgs.brightnessctl;
  playerctl = lib.getExe pkgs.playerctl;
  wpctl = lib.getExe' pkgs.wireplumber "wpctl";
in {
  home.packages = [
    pkgs.wl-clipboard
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
          "$mod" = "SUPER"; # this is the Windows key
          "$terminal" = lib.getExe pkgs.kitty;
          "$menu" = lib.getExe pkgs.fuzzel;
          animations = {
            enabled = false;
            first_launch_animation = false;
          };
          input = {
            kb_model = "pc105";
            kb_layout = "it(us),no,se";
            kb_options = "grp:alt_shift_toggle";
            #kb_variant = "colemak,,";
            scroll_method = "2fg"; # two-finger
            natural_scroll = true;
            touchpad = {
              disable_while_typing = true;
              natural_scroll = true;
              tap-to-click = true;
            };
          };
          gestures = {
            workspace_swipe = true;
          };
          misc = {
            disable_hyprland_logo = true;
          };
          binds = {
            workspace_back_and_forth = true;
            allow_workspace_cycles = true;
            # switching workspaces centers the cursor on the last active window for that workspace
            workspace_center_on = 1;
          };
          # keybindings
          bind =
            [
              ", Print, exec, ${lib.getExe pkgs.flameshot} gui"
              ", XF86AudioNext, exec, ${playerctl} next"
              ", XF86AudioPrev, exec, ${playerctl} previous"
              # TODO
              #"$mod, l, exec, ${lockCmd}"
              "ALT, p, exec, ${lib.getExe pkgs.wlogout}"
              # FIXME to be tested!
              "ALT, l, exec, movecurrentworkspacetomonitor, -1"
              "ALT, r, exec, movecurrentworkspacetomonitor, +1"
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
          # repeat (will repeat when held)
          binde = [
            ", XF86MonBrightnessUp, exec, ${brightnessctl} set 5%+"
            ", XF86MonBrightnessDown, exec, ${brightnessctl} set 5%-"
          ];
          # locked (will also work when an input inhibitor (e.g. a lockscreen) is active)
          bindl = [
            ", XF86AudioMute, exec, ${wpctl} set-mute toggle @DEFAULT_AUDIO_SINK@"
            "$mod, XF86AudioMute, exec, ${wpctl} set-mute toggle @DEFAULT_AUDIO_SOURCE@"
            ", XF86AudioPlay, exec, ${playerctl} play-pause"
          ];
          # repeat (will repeat when held) and locked (will also work when an input inhibitor (e.g. a lockscreen) is active)
          bindel = [
            ", XF86AudioRaiseVolume, exec, ${wpctl} set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
            ", XF86AudioLowerVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ];
          # TODO
          # window rules
          #windowrulev2 = [
          #];
        };
      };
    };
  };
}