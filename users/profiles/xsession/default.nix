{ config, lib, pkgs, ... }:

let
  # meaning of --no-startup-id https://faq.i3wm.org/question/561/what-is-that-thing-called-no-startup-id/index.html
  exec = "exec --no-startup-id";

  sup = "Mod1"; # this is the "Alt" key
  mod = "Mod4"; # this is the "Windows" key

  alwaysRun = [
    # FIXME application of background
    "feh --bg-fill ~/.background-image"
    "blueman-applet"
    "systemctl --user restart polybar"
  ];

  # TODO probably add 1password GUI as well?
  run = [
    "kitty"
    "brave"
    "ferdium"
    "joplin-desktop"
    "thunderbird"
  ];
in
{
  xsession = {
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
              "${mod}+Shift+e" = "${exec} emacsclient -c -n -a \'\'";
              # rofi-related keybindings
              "${sup}+p" = "${exec} rofi -show power-menu -modi power-menu:rofi-power-menu";
              "${sup}+s" = "${exec} rofi -show ssh";
              "${sup}+w" = "${exec} \"rofi -combi-modi window,windowcd -show combi -show-icons\"";
              "${sup}+b" = "${exec} rofi -show filebrowser -show-icons";
              "${sup}+j" = "move workspace to output left";
              "${sup}+l" = "move workspace to output right";
              "${sup}+a" = "${exec} autorandr --change";
              # FIXME weylus
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
      };
    };
  };
}
