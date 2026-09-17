{ pkgs, ... }:
let
  start1PasswordAfterTray = pkgs.writeShellApplication {
    name = "start-1password-after-tray";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      # 1Password does not retry tray registration if it starts before a
      # StatusNotifier watcher. Wait up to 30 seconds for Noctalia to own it.
      for _attempt in {1..300}; do
        if busctl --user get-property \
          org.kde.StatusNotifierWatcher \
          /StatusNotifierWatcher \
          org.kde.StatusNotifierWatcher \
          IsStatusNotifierHostRegistered >/dev/null 2>&1
        then
          exec 1password --silent
        fi
        sleep 0.1
      done

      exec 1password --silent
    '';
  };

  numbatTerminal = pkgs.writeShellApplication {
    name = "numbat-terminal";
    runtimeInputs = [
      pkgs.ghostty
      pkgs.jq
      pkgs.niri
      pkgs.numbat
      pkgs.util-linux
    ];
    text = builtins.readFile ./numbat-terminal.sh;
  };
in
{
  home.packages = [
    pkgs.udiskie
    pkgs.waypipe
    pkgs.wl-clipboard
    start1PasswordAfterTray
    numbatTerminal
  ];

  xdg.configFile."niri/config.kdl".text = builtins.readFile ./config.kdl;
}
