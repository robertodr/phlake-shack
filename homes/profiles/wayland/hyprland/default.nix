{
  config,
  lib,
  pkgs,
  ...
}: let
  lockCmd = "\'${pkgs.playerctl}/bin/playerctl -a pause; ${pkgs.hyprlock}/bin/hyprlock\'";

  kitty = lib.getExe pkgs.kitty;
  fuzzel = lib.getExe pkgs.fuzzel;
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
          exec-once = [
            "[workspace 1 silent] ${kitty}"
            "[workspace 2 silent] ${lib.getExe config.programs.firefox.package}"
            "[workspace 3 silent] ${lib.getExe' pkgs.ferdium "ferdium"}"
            "[workspace 4 silent] ${lib.getExe pkgs.thunderbird}"
          ];
          # keybindings
          bind =
            [
              "SUPER, RETURN, exec, ${kitty}"
              "SUPER, D, exec, ${fuzzel}"
              "SUPER, E, exec, ${lib.getExe pkgs.xfce.thunar}"
              ", Print, exec, ${lib.getExe config.services.flameshot.package} gui"
              ", XF86AudioNext, exec, ${playerctl} next"
              ", XF86AudioPrev, exec, ${playerctl} previous"
              # TODO
              #"SUPER, l, exec, ${lockCmd}"
              "ALT, P, exec, ${lib.getExe pkgs.wlogout}"
              # FIXME to be tested!
              "ALT, L, exec, movecurrentworkspacetomonitor, -1"
              "ALT, R, exec, movecurrentworkspacetomonitor, +1"
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
                    "SUPER, ${ws}, workspace, ${toString (x + 1)}"
                    "SUPER SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
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
            ", XF86AudioMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
            "SUPER, XF86AudioMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
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
