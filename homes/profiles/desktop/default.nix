{
  pkgs,
  config,
  gitbutlerPackage,
  ...
}:
{
  fonts.fontconfig.enable = true;

  home = {
    activation.createScreenshotsDir = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.xdg.userDirs.pictures}/Screenshots"
    '';

    sessionVariables.XDG_SCREENSHOTS_DIR = "${config.xdg.userDirs.pictures}/Screenshots";

    packages = with pkgs; [
      brightnessctl
      freerdp
      hotspot
      gitbutlerPackage
      meld
      ferdium
      inkscape
      nomacs
      papers
      pika-backup
      showtime
      spotify
      zoom-us
    ];
  };

  xdg.configFile."electron-flags.conf".text = ''
    --enable-features=UseOzonePlatform
    --ozone-platform=wayland
    --wayland-text-input-version=3
  '';

  imports = map (x: ./.. + ("/" + x)) [
    "ghostty"
    "insync"
    "obsidian"
    "vscode"
    "mpris-proxy"
    "vivaldi"
    "feedr"
    "gtk"
    "noctalia-shell"
    "wayland/niri"
  ];
}
