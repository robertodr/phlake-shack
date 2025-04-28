{ lib, ... }:
{
  services.network-manager-applet = {
    enable = true;
  };

  # TODO remove after switching to release-25.05
  systemd.user.services.network-manager-applet.Unit.After = lib.mkForce [
    "graphical-session.target"
    "tray.target"
  ];
}
