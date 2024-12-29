{lib, ...}: {
  services.blueman-applet = {
    enable = true;
  };

  systemd.user.services.blueman-applet.Unit.After = lib.mkForce ["graphical-session.target" "tray.target"];
}
