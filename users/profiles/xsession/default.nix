{ config, lib, pkgs, ... }:

let
  # meaning of --no-startup-id https://faq.i3wm.org/question/561/what-is-that-thing-called-no-startup-id/index.html
  exec = "exec --no-startup-id";

  sup = "Mod1"; # this is the "Alt" key
  mod = "Mod4"; # this is the "Windows" key

  alwaysRun = [
    "feh --bg-fill ~/.background-image"
    "blueman-applet"
    "systemctl --user restart polybar"
  ];

  run = [
    "kitty"
    "brave"
    "ferdium"
    "joplin-desktop"
    "thunderbird"
  ];
in
{
  enable = true;
  initExtra = ''
    feh --bg-fill ~/.background-image
    blueman-applet &
  '';
  windowManager = {
    i3 = {
      enable = true;
      package = pkgs.i3-gaps;

      config = {
        window = {
          titlebar = false;
        };
        terminal = "kitty";
        modifier = "${mod}";
        workspaceAutoBackAndForth = true;
        keybindings =
          lib.mkOptionDefault {
            "XF86AudioRaiseVolume" = "${exec} pactl set-sink-volume @DEFAULT_SINK@ +2%";
            "XF86AudioLowerVolume" = "${exec} pactl set-sink-volume @DEFAULT_SINK@ -2%";
            "XF86AudioMute" = "${exec} pactl set-sink-mute @DEFAULT_SINK@ toggle";
            "XF86AudioMicMute" = "${exec} pactl set-source-mute @DEFAULT_SINK@ toggle";
            "XF86MonBrightnessDown" = "${exec} light -U 5%";
            "XF86MonBrightnessUp" = "${exec} light -A 5%";
            "Print" = "${exec} flameshot gui";
            "${mod}+l" = "${exec} betterlockscreen -l pixel --off 5";
            "${mod}+Shift+e" = "${exec} emacsclient -c -a '' -n";
            # rofi-related keybindings
            "${sup}+p" = "${exec} rofi -show power-menu -modi power-menu:rofi-power-menu";
            "${sup}+s" = "${exec} rofi -show ssh";
            "${sup}+w" = "${exec} \"rofi -combi-modi window,windowcd -show combi -show-icons\"";
            "${sup}+b" = "${exec} rofi -show filebrowser -show-icons";
            "${sup}+j" = "move workspace to output left";
            "${sup}+l" = "move workspace to output right";
            "${sup}+a" = "${exec} autorandr --change";
            # weylus
            "${sup}+Control+w" = "${exec} weylus";
          };
        fonts =
          {
            names = [ "M PLUS 2" "FontAwesome" ];
            style = "Regular";
            size = 14.0;
          };
        defaultWorkspace = "workspace number 1";
        # notifications from Zoom are allowed to float
        floating.criteria = [{ title = "^zoom$"; }];
        # figure out how to use this with multiple screens
        #workspaceOutputAssign = [
        #  {
        #    output = "HDMI-1";
        #    workspace = "1";
        #  }
        #  {
        #    output = "HDMI-1";
        #    workspace = "2";
        #  }
        #];
        bars = [ ];
        gaps = {
          top = 60;
          inner = 5;
          outer = 3;
        };
        menu = "${pkgs.rofi}/bin/rofi -show drun -show-icons";
        assigns = {
          "2" = [
            { class = "^Brave-browser$"; instance = "^brave-browser"; }
          ];
          "3" = [{ class = "^Joplin$"; } { class = "^Ferdium$"; }];
          "4" = [{ class = "^thunderbird$"; }];
        };
        startup = [ ]
          ++
          builtins.map
            (command:
              {
                command = command;
                always = true;
                notification = false;
              }
            )
            alwaysRun
          ++
          builtins.map
            (command:
              {
                command = command;
                notification = false;
              }
            )
            run;
      };

      extraConfig = ''
        # i3-resurrect configuration from https://github.com/JonnyHaystack/i3-resurrect#example-configuration-in-i3

        # save workspace mode.
        mode "save" {
          bindsym 1 exec "i3-resurrect save -w 1 --swallow=class,instance,title"
          bindsym 2 exec "i3-resurrect save -w 2 --swallow=class,instance,title"
          bindsym 3 exec "i3-resurrect save -w 3 --swallow=class,instance,title"
          bindsym 4 exec "i3-resurrect save -w 4 --swallow=class,instance,title"
          bindsym 5 exec "i3-resurrect save -w 5 --swallow=class,instance,title"
          bindsym 6 exec "i3-resurrect save -w 6 --swallow=class,instance,title"
          bindsym 7 exec "i3-resurrect save -w 7 --swallow=class,instance,title"
          bindsym 8 exec "i3-resurrect save -w 8 --swallow=class,instance,title"
          bindsym 9 exec "i3-resurrect save -w 9 --swallow=class,instance,title"
          bindsym 0 exec "i3-resurrect save -w 10 --swallow=class,instance,title"

          # Back to normal: Enter, Escape, or s
          bindsym Return mode "default"
          bindsym Escape mode "default"
          bindsym s mode "default"
          bindsym ${mod}+s mode "default"
        }

        bindsym ${mod}+Control+s mode "save"

        # restore workspace mode.
        mode "restore" {
          bindsym 1 exec "i3-resurrect restore -w 1 --programs-only"
          bindsym 2 exec "i3-resurrect restore -w 2 --programs-only"
          bindsym 3 exec "i3-resurrect restore -w 3 --programs-only"
          bindsym 4 exec "i3-resurrect restore -w 4 --programs-only"
          bindsym 5 exec "i3-resurrect restore -w 5 --programs-only"
          bindsym 6 exec "i3-resurrect restore -w 6 --programs-only"
          bindsym 7 exec "i3-resurrect restore -w 7 --programs-only"
          bindsym 8 exec "i3-resurrect restore -w 8 --programs-only"
          bindsym 9 exec "i3-resurrect restore -w 9 --programs-only"
          bindsym 0 exec "i3-resurrect restore -w 10 --programs-only"

          bindsym ${mod}+1 exec "i3-resurrect restore -w 1 --layout-only"
          bindsym ${mod}+2 exec "i3-resurrect restore -w 2 --layout-only"
          bindsym ${mod}+3 exec "i3-resurrect restore -w 3 --layout-only"
          bindsym ${mod}+4 exec "i3-resurrect restore -w 4 --layout-only"
          bindsym ${mod}+5 exec "i3-resurrect restore -w 5 --layout-only"
          bindsym ${mod}+6 exec "i3-resurrect restore -w 6 --layout-only"
          bindsym ${mod}+7 exec "i3-resurrect restore -w 7 --layout-only"
          bindsym ${mod}+8 exec "i3-resurrect restore -w 8 --layout-only"
          bindsym ${mod}+9 exec "i3-resurrect restore -w 9 --layout-only"
          bindsym ${mod}+0 exec "i3-resurrect restore -w 10 --layout-only"

          # Back to normal: Enter, Escape, or n
          bindsym Return mode "default"
          bindsym Escape mode "default"
          bindsym n mode "default"
          bindsym ${mod}+n mode "default"
        }

        bindsym ${mod}+Control+n mode "restore"
      '';
    };
  };
}
