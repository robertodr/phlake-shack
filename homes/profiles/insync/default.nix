{ pkgs, ... }:
{
  home.packages = [ pkgs.insync ];

  # Insync ships an XDG autostart entry and pulls in four QtWebEngine
  # processes plus continuous network polling, which is a visible chunk of the
  # idle powertop report. Replace the autostart entry with a user unit
  # conditioned on mains power, so a battery-only session simply does not
  # start it.
  #
  # ConditionACPower is evaluated when the unit is started, not continuously:
  # plugging the charger in mid-session will not launch Insync retroactively.
  # Run `systemctl --user start insync` when it is wanted on battery.
  xdg.configFile."autostart/insync.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Insync
    Hidden=true
  '';

  systemd.user.services.insync = {
    Unit = {
      Description = "Insync";
      ConditionACPower = true;
      Wants = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.insync}/bin/insync start --no-daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
