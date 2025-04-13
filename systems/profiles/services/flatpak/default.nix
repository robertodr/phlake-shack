{ ... }:
{
  services.flatpak = {
    enable = true;
    packages = [
      {
        appId = "us.zoom.Zoom";
        origin = "flathub";
      }
    ];
  };
}
