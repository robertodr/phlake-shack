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

  lockCmd = "\'${pkgs.playerctl}/bin/playerctl -a pause; ${pkgs.swaylock}/bin/swaylock\'";

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
      sway = {
        enable = true;

        systemd = {
          enable = true;
          xdgAutostart = true;
        };

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
            "XF86AudioPlay" = "exec playerctl play-pause";
            "XF86AudioNext" = "exec playerctl next";
            "XF86AudioPrev" = "exec playerctl previous";
            "Print" = "exec flameshot gui";
            "${mod}+l" = "exec ${lockCmd}";
            "${mod}+Shift+e" = "exec emacsclient -c -n -a \'\'";
            "${sup}+p" = "exec ${pkgs.wlogout}/bin/wlogout";
            "${sup}+j" = "move workspace to output left";
            "${sup}+l" = "move workspace to output right";
          };

          fonts = {
            names = ["M PLUS 2" "Font Awesome 6 Free Solid"];
            style = "Regular";
          };

          output = {
            # NOTE blanket-enable adaptive sync (cannot be done per-profile) in kanshi
            "*" = {
              adaptive_sync = "on";
            };
            "eDP-1" = {
              mode = "2256x1504";
              scale = "1.5";
            };
          };

          defaultWorkspace = "workspace number 1";

          bars = [];

          menu = ''
            ${pkgs.fuzzel}/bin/fuzzel
          '';

          window = {
            titlebar = false;
            # FIXME Zoom doesn't happen to have an app_id...
            commands = [
              # inhibit idle when Zoom meeting in progress in Brave browser
              {
                command = "inhibit_idle visible";
                criteria = {
                  app_id = "firefox";
                  title = "[Mm]eeting";
                };
              }

              # inhibit idle when Zoom window is visible
              {
                command = "inhibit_idle visible";
                criteria = {
                  app_id = "zoom";
                  title = "Zoom";
                };
              }

              # center Zoom toolbar when screensharing
              {
                command = "floating enable move position 50ppt 0 move left 402";
                criteria = {
                  app_id = "zoom";
                  title = "Zoom";
                };
              }

              # float any zoom window by default...
              {
                command = "floating enable";
                criteria = {
                  app_id = "zoom";
                  title = "Zoom";
                };
              }

              # ...except these ones
              {
                command = "floating disable";
                criteria = {
                  app_id = "zoom";
                  title = "(Account|Chat|Meeting|Participants)";
                };
              }
            ];
          };

          assigns = {
            "number 2" = [
              {
                app_id = "^firefox$";
              }
            ];
            "number 3" = [
              {app_id = "^@joplin";}
              {app_id = "^ferdium$";}
              {
                instance = "^ferdium$";
                class = "^Ferdium$";
              }
            ];
            "number 4" = [{app_id = "^thunderbird$";}];
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
