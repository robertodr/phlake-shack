{
  pkgs,
  lib,
  ...
}:
let
  wallpaper = pkgs.fetchurl {
    url = "https://www.pixelstalk.net/wp-content/uploads/2016/10/Paint-pattern-colored-abstract-background.jpg";
    sha256 = "sha256-kEdO+d3LXsRQdyyKck4YTkkwqz//CK8Z+RzXC9DSIpw=";
  };
in
{
  stylix = {
    enable = true;

    # NOTE: this is actually not used anywhere!
    # https://github.com/danth/stylix/issues/442
    image = wallpaper;

    base16Scheme = "${pkgs.base16-schemes}/share/themes/helios.yaml";

    polarity = "dark";

    cursor = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 32;
    };

    fonts = {
      serif = {
        name = "Gentium";
        package = pkgs.gentium;
      };

      sansSerif = {
        name = "M PLUS 2 Regular";
        package = pkgs.mplus-outline-fonts.githubRelease;
      };

      monospace = {
        name = "JuliaMono";
        package = pkgs.julia-mono;
      };

      emoji = {
        name = "Noto Color Emoji";
        package = pkgs.noto-fonts-emoji;
      };

      sizes = {
        desktop = 12;
        applications = 14;
        terminal = 14;
        popups = 12;
      };
    };

    opacity = {
      popups = 0.50;
      desktop = 0.90;
    };

    targets = {
      grub = {
        enable = true;
        useImage = true;
      };
      plymouth.enable = false;
    };
  };

  home-manager.users.roberto = {
    stylix.targets = {
      emacs.enable = false;
      hyprlock.enable = false;
      hyprpaper.enable = lib.mkDefault false;
      vscode.enable = false;
      waybar.enable = false;
    };
  };
}
