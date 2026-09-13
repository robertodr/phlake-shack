{ lib, ... }:
{
  services.blueman-applet = {
    enable = true;
  };

  # The system package also ships an XDG autostart entry. Let the Home
  # Manager service own startup to avoid racing applets and OBEX agents.
  xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Blueman Applet
    Hidden=true
  '';
}
