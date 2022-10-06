{
  config,
  lib,
  pkgs,
  ...
}: let
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
    "\"brave --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland\""
    "\"ferdium --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland\""
    "thunderbird"
    # FIXME Joplin looks crappy with Wayland, but the electron flags do not work...
    "joplin-desktop"
  ];
in {
  home.packages = with pkgs; [
    cliphist
    thunderbird-wayland
  ];

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

          keybindings = lib.mkOptionDefault {
            "XF86AudioRaiseVolume" = "exec ${pkgs.pamixer}/bin/pamixer -i 5";
            "XF86AudioLowerVolume" = "exec ${pkgs.pamixer}/bin/pamixer -d 5";
            "XF86AudioMute" = "exec ${pkgs.pamixer}/bin/pamixer -t";
            "XF86AudioMicMute" = "exec ${pkgs.pamixer}/bin/pamixer --default-source -t";
            "XF86MonBrightnessDown" = "exec ${pkgs.light}/bin/light -U 5%";
            "XF86MonBrightnessUp" = "exec ${pkgs.light}/bin/light -A 5%";
            "Print" = "exec flameshot gui";
            "${mod}+l" = "exec swaylock -k -l";
            "${mod}+Shift+e" = "exec emacsclient -c -n -a \'\'";
            "${sup}+p" = "exec ${pkgs.wlogout}/bin/wlogout";
            "${sup}+j" = "move workspace to output left";
            "${sup}+l" = "move workspace to output right";
            # FIXME we're using kanshi!
            #"${sup}+a" = "exec autorandr --change";
            # FIXME weylus
            "${sup}+Control+w" = "exec weylus";
          };

          fonts = {
            names = ["M PLUS 2" "FontAwesome"];
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
          floating.criteria = [{title = "^zoom$";}];

          bars = [];

          menu = "${pkgs.fuzzel}/bin/fuzzel";

          assigns = {
            "2" = [
              {
                app_id = "^brave-browser$";
              }
            ];
            "3" = [{class = "^Joplin$";} {app_id = "^ferdium$";}];
            "4" = [{app_id = "^thunderbird$";}];
          };

          startup =
            []
            ++ builtins.map
            (
              command: {
                command = command;
                always = true;
              }
            )
            alwaysRun
            ++ builtins.map
            (
              command: {
                command = command;
              }
            )
            run;
        };
      };
    };
  };
}
