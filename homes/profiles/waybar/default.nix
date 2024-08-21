{
  config,
  pkgs,
  lib,
  ...
}: let
  wttr =
    pkgs.writers.writePython3Bin "wttr.py"
    {
      libraries = [pkgs.python3Packages.requests];
    }
    (builtins.readFile ./wttr.py);
in {
  # TODO review styling, especially colors!
  programs.waybar = {
    enable = true;

    systemd.enable = true;

    # TODO figure out whether I want this override or not
    #package = pkgs.waybar.override {
    #  withMediaPlayer = true;
    #};

    settings = {
      mainBar = {
        layer = "top";

        position = "top";

        # top|left|bottom|right
        margin = "5 2 5 2";

        modules-left = [
          "sway/workspaces"
          "sway/language"
          "pulseaudio"
          "idle_inhibitor"
        ];

        modules-center = [
          "clock"
          "custom/weather"
        ];

        modules-right = [
          "memory"
          "cpu"
          "battery"
          "tray"
        ];

        "sway/workspaces" = {
          disable-scroll = true;
          format = "{name}";
        };

        "sway/language" = {
          format = "{short} {variant} ";
          on-click = "${pkgs.sway}/bin/swaymsg input type:keyboard xkb_switch_layout next";
          tooltip = false;
        };

        pulseaudio = {
          reverse-scrolling = 1;
          format = "{volume}% {icon} {format_source}";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = " {format_source}";
          format-source = " {volume}%";
          format-source-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = ["" "" ""];
          };
          on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
          min-length = 13;
        };

        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "";
            deactivated = "";
          };
        };

        clock = {
          format = "{:%A  %d %B  %H:%M}";
          tooltip = true;
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          today-format = "<span color='#ff6699'><b><u>{}</u></b></span>";
          format-calendar = "<span color='#ecc6d9'><b>{}</b></span>";
          format-calendar-weekdays = "<span color='#ffcc66'><b>{}</b></span>";
          calendar-weeks-pos = "right";
          format-calendar-weeks = "<span color='#99ffdd'><b><tt><small>{:%V}</small></tt></b></span>";
        };

        "custom/weather" = {
          format = "{}";
          tooltip = true;
          interval = 1800;
          exec = "${wttr}/bin/wttr.py";
          return-type = "json";
        };

        memory = {
          interval = 30;
          format = "{}% ";
        };

        cpu = {
          interval = 10;
          format = "{}% ";
        };

        battery = {
          states = {
            good = 95;
            warning = 30;
            critical = 15;
          };
          format = "{capacity}% {icon}";
          format-charging = "{capacity}% ";
          format-plugged = "{capacity}% ";
          format-alt = "{time} {icon}";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
        };

        "tray" = {
          icon-size = 25;
          show-passive-items = true;
          spacing = 5;
        };
      };
    };

    style = lib.mkDefault ''
      * {
        border: none;
        border-radius: 0;
        font-family: "M PLUS 2 Regular", "Font Awesome 6 Free Solid", "Weather Icons";
        min-height: 20px;
      }

      window#waybar {
        background: transparent;
      }

      window#waybar.hidden {
          opacity: 0.2;
      }

      #workspaces {
          margin-right: 8px;
          border-radius: 10px;
          transition: none;
          background: #383c4a;
      }

      #workspaces button {
          transition: none;
          color: #7c818c;
          background: transparent;
          padding: 5px;
          font-size: 18px;
      }

      #workspaces button.persistent {
          color: #7c818c;
          font-size: 12px;
      }

      /* https://github.com/Alexays/Waybar/wiki/FAQ#the-workspace-buttons-have-a-strange-hover-effect */
      #workspaces button:hover {
          transition: none;
          box-shadow: inherit;
          text-shadow: inherit;
          border-radius: inherit;
          color: #383c4a;
          background: #7c818c;
      }

      #workspaces button.focused {
          color: white;
      }

      #language {
          padding-left: 16px;
          padding-right: 8px;
          margin-right: 8px;
          border-radius: 10px;
          transition: none;
          color: #ffffff;
          background: #383c4a;
      }

      #clock {
          padding-left: 16px;
          padding-right: 16px;
          border-radius: 10px 0px 0px 10px;
          transition: none;
          color: #ffffff;
          background: #383c4a;
      }

      #custom-weather {
          padding-right: 16px;
          border-radius: 0px 10px 10px 0px;
          transition: none;
          color: #ffffff;
          background: #383c4a;
      }

      #pulseaudio {
          margin-right: 8px;
          padding-left: 16px;
          padding-right: 16px;
          border-radius: 10px;
          transition: none;
          color: #ffffff;
          background: #383c4a;
      }

      #pulseaudio.muted {
          background-color: #90b1b1;
          color: #2a5c45;
      }

      #idle_inhibitor {
          padding-left: 16px;
          padding-right: 16px;
          border-radius: 10px;
          transition: none;
          color: #ffffff;
          background: #383c4a;
      }

      #cpu,
      #memory {
          margin-right: 8px;
          padding-left: 16px;
          padding-right: 16px;
          border-radius: 10px;
          transition: none;
          color: #ffffff;
          background: #383c4a;
      }

      #battery {
          margin-right: 8px;
          padding-left: 16px;
          padding-right: 16px;
          border-radius: 10px;
          transition: none;
          color: #ffffff;
          background: #383c4a;
      }

      #battery.charging {
          color: #ffffff;
          background-color: #26A65B;
      }

      #battery.warning:not(.charging) {
          background-color: #ffbe61;
          color: black;
      }

      #battery.critical:not(.charging) {
          background-color: #f53c3c;
          color: #ffffff;
          animation-name: blink;
          animation-duration: 0.5s;
          animation-timing-function: linear;
          animation-iteration-count: infinite;
          animation-direction: alternate;
      }

      #tray {
          padding-left: 16px;
          padding-right: 16px;
          border-radius: 10px;
          transition: none;
          color: #ffffff;
          background: #383c4a;
      }

      @keyframes blink {
          to {
              background-color: #ffffff;
              color: #000000;
          }
      }
    '';
  };
}
