{
  config,
  lib,
  pkgs,
  ...
}: let
  kitty = lib.getExe pkgs.kitty;
  fuzzel = lib.getExe pkgs.fuzzel;
  brightnessctl = lib.getExe pkgs.brightnessctl;
  playerctl = lib.getExe config.services.playerctld.package;
  wpctl = lib.getExe' pkgs.wireplumber "wpctl";
  clipse = lib.getExe pkgs.unstable.clipse;

  locker = pkgs.writeShellScriptBin "locker.sh" ''
    ${playerctl} -a pause
    ${lib.getExe config.programs.hyprlock.package}
  '';
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

        plugins = [pkgs.hyprlandPlugins.hy3];

        settings = {
          animations = {
            enabled = false;
            first_launch_animation = false;
          };
          general = {
            layout = "hy3";
            gaps_in = 2;
            gaps_out = 4;
            border_size = 1;
            resize_on_border = true;
          };
          decoration = {
            rounding = 10;
            drop_shadow = false;
            blur = {enabled = false;};
          };
          input = {
            kb_model = "pc104"; # ANSI
            kb_layout = "it(us),no,se,us(colemak)";
            kb_options = "grp:alt_shift_toggle,";
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
            disable_splash_rendering = true;
            key_press_enables_dpms = true;
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
            # TODO remove when there is a clipse module in home-manager
            "${clipse} -listen"
          ];
          # keybindings
          # l -> locked, will also work when an input inhibitor (e.g. a lockscreen) is active.
          # r -> release, will trigger on release of a key.
          # e -> repeat, will repeat when held.
          # n -> non-consuming, key/mouse events will be passed to the active window in addition to triggering the dispatcher.
          # m -> mouse, see below.
          # t -> transparent, cannot be shadowed by other binds.
          # i -> ignore mods, will ignore modifiers.
          # s -> separate, will arbitrarily combine keys between each mod/key, see [Keysym combos](#keysym-combos) above.
          # d -> has description, will allow you to write a description for your bind.
          # p -> bypasses the app's requests to inhibit keybinds.
          bindd =
            [
              "SUPER, RETURN, Open kitty, exec, ${kitty}"
              "SUPER, D, Open Fuzzel, exec, ${fuzzel}"
              "SUPER SHIFT, E, Open Thunar, exec, ${lib.getExe pkgs.xfce.thunar}"
              "SUPER, L, Lock screen, exec, ${lib.getExe locker}"
              "ALT, P, Logout menu, exec, ${lib.getExe config.programs.wlogout.package}"
              # FIXME to be tested!
              "ALT, L, Move current workspace to monitor on the left, exec, movecurrentworkspacetomonitor, -1"
              "ALT, R, Move current workspace to monitor on the right, exec, movecurrentworkspacetomonitor, +1"
              "SUPER SHIFT, Q, Close window, hy3:killactive"
              "SUPER, F, Maximize focused window, fullscreen, 1"
              "SUPER, V, Make a vertical split group, hy3:makegroup, h"
              "SUPER, B, Make a horizontal split group, hy3:makegroup, v"
              "SUPER, E, Toggle between horizontal/vertical group, hy3:changegroup, opposite"
              "SUPER, W, Toggle tab status of group, hy3:changegroup, toggletab"
              "SUPER SHIFT, SPACE, Toggle floating, togglefloating"
              "SUPER, LEFT, Focus window left, hy3:movefocus, l"
              "SUPER, DOWN, Focus window down, hy3:movefocus, d"
              "SUPER, UP, Focus window up, hy3:movefocus, u"
              "SUPER, RIGHT, Focus window right:, hy3:movefocus, r"
              "SUPER SHIFT, LEFT, Move window left, hy3:movewindow, l, once"
              "SUPER SHIFT, DOWN, Move window down, hy3:movewindow, d, once"
              "SUPER SHIFT, UP, Move window up, hy3:movewindow, u, once"
              "SUPER SHIFT, RIGHT, Move window right, hy3:movewindow, r, once"
              "SUPER, C, Open clipse, exec, ${kitty} --class clipse -e ${lib.getExe config.programs.fish.package} -c '${clipse} -fc $fish_pid'"
              # special  keys
              ", Print, Screenshot area with grimblast, exec, ${lib.getExe pkgs.grimblast} copysave area"
              ", XF86AudioNext, Play next, exec, ${playerctl} next"
              ", XF86AudioPrev, Play previous, exec, ${playerctl} previous"
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
                    "SUPER, ${ws}, Go to workspace ${toString (x + 1)}, workspace, ${toString (x + 1)}"
                    "SUPER SHIFT, ${ws}, Move to worspace ${toString (x + 1)}, movetoworkspace, ${toString (x + 1)}"
                  ]
                )
                10)
            );
          # repeat (will repeat when held)
          bindde = [
            ", XF86MonBrightnessUp, Increase laptop screen brightness, exec, ${brightnessctl} --device=intel_backlight set 5%+"
            ", XF86MonBrightnessDown,Decrease laptop screen brightness, exec, ${brightnessctl} --device=intel_backlight set 5%-"
          ];
          # locked (will also work when an input inhibitor (e.g. a lockscreen) is active)
          binddl = [
            ", XF86AudioMute, Mute speakers, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
            "SUPER, XF86AudioMute, Mute microphone, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
            ", XF86AudioPlay, Toggle play/pause, exec, ${playerctl} play-pause"
          ];
          # repeat (will repeat when held) and locked (will also work when an input inhibitor (e.g. a lockscreen) is active)
          binddel = [
            ", XF86AudioRaiseVolume, Raise volume, exec, ${wpctl} set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
            ", XF86AudioLowerVolume, Lower volume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ];
          # TODO this can be managed with shikane
          monitor = [
            "eDP-1, 2256x1504@60, auto, 1.6"
          ];
          # window rules
          windowrulev2 = [
            "workspace 2, class:(firefox)"
            "workspace 3, class:(ferdium)"
            "workspace 4, class:(thunderbird)"
            "float, class:(clipse)"
            "size 1200 600, class:(clipse)"
          ];
        };
      };
    };
  };
}
