{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  locker = pkgs.writeShellScriptBin "locker.sh" ''
    playerctl -a pause
    # this is copy-pasted from runOnce
    pgrep hyprlock || uwsm app -- hyprlock
  '';

  toggle = program: let
    prog = builtins.substring 0 14 program;
  in "pkill ${prog} || uwsm app -- ${program}";

  runOnce = program: "pgrep ${program} || uwsm app -- ${program}";
in {
  home = {
    packages = [
      pkgs.drawing
      pkgs.grimblast
      pkgsUnstable.waypipe
      pkgs.wl-clipboard
    ];

    sessionVariables = {
      GRIMBLAST_EDITOR = "drawing";
    };
  };

  wayland = {
    windowManager = {
      hyprland = {
        enable = true;

        xwayland.enable = true;

        # see: https://wiki.hyprland.org/Useful-Utilities/Systemd-start
        systemd.enable = false;

        plugins = with pkgs.hyprlandPlugins; [
          hy3
          hyprspace
        ];

        settings = {
          animations = {
            enabled = false;
            first_launch_animation = false;
          };
          debug = {
            disable_logs = false;
            disable_time = false;
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
            shadow = {enabled = false;};
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
          plugin = {
            hyprspace = {overview = {autoDrag = false;};};
          };
          exec-once = [
            # finalize startup
            "uwsm finalize"
            "[workspace 1 silent] uwsm app -- kitty"
            "[workspace 2 silent] uwsm app -- firefox"
            "[workspace 3 silent] uwsm app -- ferdium"
            "[workspace 4 silent] uwsm app -- thunderbird"
            # start udiskie in the tray
            "uwsm app -- ${lib.getExe' pkgs.udiskie "udiskie"} --smart-tray"
            # start 1password in the tray
            "uwsm app -- 1password --silent"
          ];
          # keybindings
          # l -> locked, will also work when an input inhibitor (e.g. a lockscreen) is active.
          # r -> release, will trigger on release of a key.
          # e -> repeat, will repeat when held.
          # n -> non-consuming, key/mouse events will be passed to the active window in addition to triggering the dispatcher.
          # m -> mouse, see below.
          # t -> transparent, cannot be shadowed by other binds.
          # i -> ignore mods, will ignore modifiers.
          # s -> separate, will arbitrarily combine keys between each mod/key.
          # d -> has description, will allow you to write a description for your bind.
          # p -> bypasses the app's requests to inhibit keybinds.
          bindd =
            [
              "SUPER, RETURN, Open kitty, exec, uwsm app -- kitty"
              "SUPER, D, Open Fuzzel, exec, ${toggle "fuzzel"}"
              "SUPER SHIFT, E, Open Thunar, exec, ${lib.getExe pkgs.xfce.thunar}"
              "SUPER, L, Lock screen, exec, ${lib.getExe locker}"
              "SUPER, ESCAPE, Logout menu, exec, ${toggle "wlogout"} -p layer-shell"
              "ALT, L, Move current workspace to monitor on the left, movecurrentworkspacetomonitor, l"
              "ALT, R, Move current workspace to monitor on the right, movecurrentworkspacetomonitor, r"
              "ALT, U, Move current workspace to monitor up, movecurrentworkspacetomonitor, u"
              "ALT, D, Move current workspace to monitor down, movecurrentworkspacetomonitor, d"
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
              "SUPER, C, Open clipse, exec, uwsm app -- kitty --class clipse -e ${lib.getExe config.programs.fish.package} -c 'clipse -fc $fish_pid'"
              "SUPER, N, Open numbat, exec, uwsm app -- kitty --class numbat -e ${lib.getExe pkgs.numbat}"
              "SUPER, Y, Open yazi, exec, uwsm app -- kitty --class yazi -e ${lib.getExe config.programs.yazi.package}"
              "SUPER, TAB, Hyprspace workspace overview, overview:toggle"
              # special  keys
              ", Print, Screenshot area with grimblast, exec, ${runOnce "grimblast"} --notify copysave area"
              "SUPER, Print, Screenshot area with grimblast and open editor, exec, ${runOnce "grimblast"} --notify edit area"
              ", XF86AudioNext, Play next, exec, playerctl next"
              ", XF86AudioPrev, Play previous, exec, playerctl previous"
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
                    # go to workspace
                    "SUPER, ${ws}, Go to workspace ${toString (x + 1)}, workspace, ${toString (x + 1)}"
                    # move window to workspace, but don't go to workspace
                    "SUPER SHIFT, ${ws}, Move window to worspace ${toString (x + 1)}, movetoworkspacesilent, ${toString (x + 1)}"
                  ]
                )
                10)
            );
          # repeat (will repeat when held)
          bindde = [
            ", XF86MonBrightnessUp, Increase laptop screen brightness, exec, brightnessctl --device=intel_backlight set 5%+"
            ", XF86MonBrightnessDown,Decrease laptop screen brightness, exec, brightnessctl --device=intel_backlight set 5%-"
          ];
          # locked (will also work when an input inhibitor (e.g. a lockscreen) is active)
          binddl = [
            ", XF86AudioMute, Mute speakers, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
            "SUPER, XF86AudioMute, Mute microphone, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
            ", XF86AudioPlay, Toggle play/pause, exec, playerctl play-pause"
            ", switch:on:Lid Switch, Turn off laptop display on lid close, exec, hyprctl dispatch dpms off"
            ", switch:off:Lid Switch, Turn on laptop display on lid close, exec, hyprctl dispatch dpms on"
          ];
          # repeat (will repeat when held) and locked (will also work when an input inhibitor (e.g. a lockscreen) is active)
          binddel = [
            ", XF86AudioRaiseVolume, Raise volume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
            ", XF86AudioLowerVolume, Lower volume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ];
          # window rules
          windowrulev2 = [
            "workspace 2, class:(firefox)"
            "workspace 3, class:(ferdium)"
            "workspace 4, class:(thunderbird)"
            "float, class:(clipse)"
            "size 1200 600, class:(clipse)"
            "float, class:(numbat)"
            "size 1200 600, class:(numbat)"
            "float, class:(yazi)"
            "size 1200 1200, class:(numbat)"
            "float, title:(1Password)"
            "size 1200 600, title:(1Password)"
            "center, title:(1Password)"
          ];
        };
      };
    };
  };
}
