{
  lib,
  pkgs,
  config,
  ...
}: let
  wallpaperLaptop = pkgs.fetchurl {
    url = "https://w.wallhaven.cc/full/nm/wallhaven-nmeo81.png";
    sha256 = "sha256-HhUXLU+QqYYY07LdxVF6bAKevSzPaJXbAYm6qf4g7rc=";
  };
  wallpaper = pkgs.fetchurl {
    url = "https://w.wallhaven.cc/full/1p/wallhaven-1pewy3.png";
    sha256 = "sha256-nk2IoRxKa4Y7k5PsrfqrH4sIoPk+h3WnIp25rABzQPg=";
  };
in {
  services.hyprpaper = {
    enable = lib.mkForce true;

    settings = {
      preload = ["${wallpaper}" "${wallpaperLaptop}"];
      wallpaper = [", ${wallpaper}" "eDP-1, ${wallpaperLaptop}"];
    };
  };

  systemd.user.services.hyprpaper.Unit.After = lib.mkForce "graphical-session.target";
}
