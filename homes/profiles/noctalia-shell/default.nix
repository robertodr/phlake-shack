{
  config,
  lib,
  pkgs,
  ...
}:
let
  wallpaperLaptop = pkgs.fetchurl {
    url = "https://w.wallhaven.cc/full/nm/wallhaven-nmeo81.png";
    sha256 = "sha256-HhUXLU+QqYYY07LdxVF6bAKevSzPaJXbAYm6qf4g7rc=";
  };
  wallpaper = pkgs.fetchurl {
    url = "https://w.wallhaven.cc/full/1p/wallhaven-1pewy3.png";
    sha256 = "sha256-nk2IoRxKa4Y7k5PsrfqrH4sIoPk+h3WnIp25rABzQPg=";
  };
in
{
  programs.noctalia = {
    enable = true;
    systemd.enable = true;

    settings = {
      shell = {
        font_family = "M PLUS 2";
        clipboard_enabled = true;
        clipboard_keep_from_closed_apps = true;
        clipboard_history_max_entries = 100;
        clipboard_confirm_clear_history = true;
        clipboard_auto_paste = "auto";
        launch_apps_as_systemd_services = true;
        polkit_agent = true;

        greeter_sync = {
          auto_sync = true;
          privilege_command = "";
        };

        screenshot = {
          save_to_file = true;
          directory = "${config.xdg.userDirs.pictures}/Screenshots";
          filename_pattern = "Screenshot_%Y-%m-%d_%H-%M-%S";
          copy_to_clipboard = true;
          freeze_screen = true;
          confirm_region = false;
          remember_last_region = false;
          show_cursor = false;
          annotate = true;
          close_on_copy = true;
          pipe_to_command = false;
        };
      };
      wallpaper = {
        enabled = true;
        fill_mode = "crop";
        transition_on_startup = false;
        default.path = "${wallpaper}";
      };
      hooks = {
        started = [
          "noctalia msg wallpaper-set '${wallpaper}'"
          "noctalia msg wallpaper-set eDP-1 '${wallpaperLaptop}'"
        ];
        session_locked = "playerctl -a pause";
      };
      notification.enable_daemon = true;
      lockscreen = {
        enabled = true;
        lock_before_suspend = true;
        fingerprint = true;
        allow_empty_password = false;
        wallpaper = "";
      };
      idle = {
        behavior_order = [
          "display-dim"
          "keyboard-backlight-off"
          "lock"
          "screen-off"
          "suspend"
        ];
        pre_action_fade_seconds = 0.0;

        behavior = {
          "display-dim" = {
            timeout = 300;
            action = "command";
            command = "${lib.getExe pkgs.brightnessctl} -s set 10";
            resume_command = "${lib.getExe pkgs.brightnessctl} -r";
          };
          "keyboard-backlight-off" = {
            timeout = 300;
            action = "command";
            command = "${lib.getExe pkgs.brightnessctl} -sd '*::kbd_backlight' set 0";
            resume_command = "${lib.getExe pkgs.brightnessctl} -rd '*::kbd_backlight'";
          };
          lock = {
            timeout = 360;
            action = "lock";
          };
          "screen-off" = {
            timeout = 390;
            action = "screen_off";
          };
          suspend = {
            timeout = 3600;
            action = "command";
            command = "systemctl suspend-then-hibernate";
          };
        };
      };
      dock.enabled = false;

      osd.enabled = true;

      # Open-Meteo provides weather while the shared fixed location also drives
      # the night-light schedule formerly managed by Gammastep.
      weather = {
        enabled = true;
        refresh_minutes = 30;
        unit = "metric";
        effects = false;
      };
      location = {
        auto_locate = false;
        latitude = 59.96869229547849;
        longitude = 10.867898284676471;
      };
      nightlight = {
        enabled = true;
        force = false;
        temperature_day = 5500;
        temperature_night = 3700;
      };

      system.monitor = {
        enabled = true;
        cpu_poll_seconds = 10.0;
        memory_poll_seconds = 30.0;
        # Disable unused collectors so this bar has the same monitoring scope
        # and cadence as the Waybar configuration.
        gpu_poll_seconds = 0.0;
        network_poll_seconds = 0.0;
        disk_poll_seconds = 0.0;
      };

      battery.warning_threshold = 30;

      bar = {
        order = [ "main" ];
        main = {
          enabled = true;
          layer = "top";
          position = "top";
          reserve_space = true;
          auto_hide = false;
          thickness = 34;
          background_opacity = 0.0;
          shadow = false;
          radius = 0;
          margin_edge = 5;
          margin_ends = 2;
          padding = 0;
          widget_spacing = 8;
          hover_highlight = true;
          font_family = "M PLUS 2";

          start = [
            "caffeine"
            "keyboard_layout"
            "group:audio"
            "workspaces"
            "active_window"
          ];
          center = [ "group:clock-weather" ];
          end = [
            "group:hardware"
            "network"
            "bluetooth"
            "notifications"
            "tray"
          ];

          capsule_group = [
            {
              id = "audio";
              members = [
                "output_volume"
                "input_volume"
              ];
              fill = "#383c4a";
              foreground = "#ffffff";
              padding = 8.0;
              radius = 10.0;
              opacity = 1.0;
              widget_spacing = 6;
            }
            {
              id = "clock-weather";
              members = [
                "clock"
                "weather"
              ];
              fill = "#383c4a";
              foreground = "#ffffff";
              padding = 10.0;
              radius = 10.0;
              opacity = 1.0;
              widget_spacing = 6;
            }
            {
              id = "hardware";
              members = [
                "hardware-toggle"
                "cpu"
                "memory"
                "battery"
              ];
              fill = "#383c4a";
              foreground = "#ffffff";
              padding = 8.0;
              radius = 10.0;
              opacity = 1.0;
              accordion = true;
              accordion_direction = "start";
              widget_spacing = 8;
            }
          ];
        };
      };

      widget = {
        caffeine = {
          capsule = true;
          capsule_fill = "#383c4a";
          capsule_foreground = "#ffffff";
          capsule_padding = 16.0;
          capsule_radius = 10.0;
        };

        keyboard_layout = {
          display = "short";
          show_glyph = false;
          show_label = true;
          hide_when_single_layout = false;
          capsule = true;
          capsule_fill = "#383c4a";
          capsule_foreground = "#ffffff";
          capsule_padding = 8.0;
          capsule_radius = 10.0;
          actions.left = "none";
        };

        output_volume = {
          device = "output";
          show_label = true;
          mute_color = "#90b1b1";
          actions = {
            left = "exec ${lib.getExe pkgs.pavucontrol}";
            scroll_up = "volume-down";
            scroll_down = "volume-up";
          };
        };

        input_volume = {
          device = "input";
          show_label = true;
          hide_when_inactive = false;
          mute_color = "#90b1b1";
          actions = {
            left = "exec ${lib.getExe pkgs.pavucontrol}";
            # Waybar treated its combined sink/source display as one scroll
            # target, so scrolling either half still adjusts the output.
            scroll_up = "volume-down";
            scroll_down = "volume-up";
          };
        };

        workspaces = {
          style = "regular";
          show_labels = true;
          show_icons = false;
          label_source = "id";
          max_label_chars = 2;
          labels_only_when_occupied = false;
          hide_when_empty = false;
          show_all_outputs = false;
          active_pill_size = 1.5;
          inactive_pill_size = 1.0;
          focused_color = "#ffffff";
          occupied_color = "#7c818c";
          empty_color = "#7c818c";
          urgent_color = "#f53c3c";
          capsule = true;
          capsule_fill = "#383c4a";
          capsule_foreground = "#ffffff";
          capsule_padding = 5.0;
          capsule_radius = 10.0;
        };

        active_window = {
          display = "icon_and_text";
          min_length = 0.0;
          max_length = 260.0;
          icon_size = 18.0;
          title_scroll = "none";
          show_empty_label = false;
        };

        clock = {
          format = "{:%A, %e %R (%Z)}";
          tooltip_format = "{:%A, %B %e, %Y}";
          actions.right = "panel-toggle control-center calendar";
        };

        weather = {
          max_length = 160.0;
          show_condition = false;
          show_temperature = true;
        };

        "hardware-toggle" = {
          type = "custom_button";
          glyph = "device-desktop";
          label = "HW";
          interactive = false;
        };

        cpu = {
          type = "sysmon";
          stat = "cpu_usage";
          visualization = "gauge";
          show_value = false;
          show_glyph = true;
          highlight_color = "#dd532e";
        };

        memory = {
          type = "sysmon";
          stat = "ram_pct";
          visualization = "none";
          show_value = true;
          label_show_units = true;
          show_glyph = true;
          highlight_color = "#dd532e";
        };

        battery = {
          type = "battery";
          device = "auto";
          display_mode = "glyph";
          show_label = true;
          label_content = "percent";
          hide_when_plugged = false;
          hide_when_full = false;
          warning_color = "#f53c3c";
        };

        network.type = "network";
        bluetooth.type = "bluetooth";
        notifications.type = "notifications";

        tray = {
          hide_passive = false;
          drawer = false;
          match_adjacent_spacing = false;
          scale = 1.4;
          capsule = true;
          capsule_fill = "#383c4a";
          capsule_foreground = "#ffffff";
          capsule_padding = 10.0;
          capsule_radius = 10.0;
        };
      };
    };
  };

  # pam_systemd can activate graphical-session.target before Niri has created
  # its Wayland socket during an interactive greetd login. Tie Noctalia to the
  # compositor service so it starts only after Niri reports readiness.
  systemd.user.services.noctalia = {
    Unit.After = lib.mkForce [ "niri.service" ];
    Install.WantedBy = lib.mkForce [ "niri.service" ];
  };
}
