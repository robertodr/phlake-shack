{ config, lib, pkgs, ... }:

let
  sup = "Mod1"; # this is the "Alt" key
  mod = "Mod4"; # this is the "Windows" key

  alwaysRun = [
    # FIXME application of background
    #"feh --bg-fill ~/.background-image"
    "blueman-applet"
    #"systemctl --user restart polybar"
  ];

  # TODO probably add 1password GUI as well?
  run = [
    "kitty"
    "brave --enable-features=UseOzonePlatform --ozone-platform=wayland"
    "ferdium"
    "joplin-desktop"
    "thunderbird"
  ];
in
{
  wayland = {
    windowManager = {
      sway = {
        enable = true;

        systemdIntegration = true;

        wrapperFeatures = {
          base = true;
          gtk = true;
        };

        config = {
          input = {
            "type:keyboard" = {
              xkb_layout = "it(us),no,se";
              xkb_model = "pc105";
              xkb_options = "grp:alt_shift_toggle";
              #xkb_variant = "colemak,,";
              #xkb_numlock = "enabled";
            };
            "type:mouse" = {
              natural_scroll = "enabled";
            };
            "type:touchpad" = {
              click_method = "clickfinger";
              natural_scroll = "enabled";
              scroll_method = "two_finger";
              tap = "enabled";
            };
          };

          window = {
            titlebar = false;
          };

          terminal = "kitty";

          modifier = "${mod}";

          workspaceAutoBackAndForth = true;

          keybindings =
            lib.mkOptionDefault {
              # FIXME audio buttons
              "XF86AudioRaiseVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ +2%";
              "XF86AudioLowerVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ -2%";
              "XF86AudioMute" = "exec pactl set-sink-mute @DEFAULT_SINK@ toggle";
              "XF86AudioMicMute" = "exec pactl set-source-mute @DEFAULT_SINK@ toggle";
              "XF86MonBrightnessDown" = "exec ${pkgs.light}/bin/light -U 5%";
              "XF86MonBrightnessUp" = "exec ${pkgs.light}/bin/light -A 5%";
              "Print" = "exec flameshot gui";
              # FIXME we're using swaylock!
              #"${mod}+l" = "exec betterlockscreen -l pixel --off 5";
              "${mod}+Shift+e" = "exec emacsclient -c -n -a \'\'";
              # rofi-related keybindings
              "${sup}+p" = "exec rofi -show power-menu -modi power-menu:rofi-power-menu";
              "${sup}+s" = "exec rofi -show ssh";
              "${sup}+w" = "exec \"rofi -combi-modi window,windowcd -show combi -show-icons\"";
              "${sup}+b" = "exec rofi -show filebrowser -show-icons";
              "${sup}+j" = "move workspace to output left";
              "${sup}+l" = "move workspace to output right";
              # FIXME we're using kanshi!
              #"${sup}+a" = "exec autorandr --change";
              # FIXME weylus
              "${sup}+Control+w" = "exec weylus";
            };

          fonts =
            {
              names = [ "M PLUS 2" "FontAwesome" ];
              style = "Regular";
              size = 14.0;
            };

          # TODO figure out how to switch based on hostname
          # see: https://git.sr.ht/~jshholland/nixos-configs/tree/master/item/home/sway.nix
          output = {
            "eDP-1" = {
              mode = "2256x1504";
              scale = "1.5";
            };
          };

          defaultWorkspace = "workspace number 1";

          # notifications from Zoom are allowed to float
          floating.criteria = [{ title = "^zoom$"; }];

          bars = [ ];

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
                }
              )
              alwaysRun
            ++
            builtins.map
              (command:
                {
                  command = command;
                }
              )
              run;
        };
      };
    };
  };

  home.packages = with pkgs; [
    cliphist
  ];
}
