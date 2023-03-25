{
  pkgs,
  lib,
  ...
}: {
  gtk = {
    enable = true;

    cursorTheme = {
      name = "phinger-cursors";
      package = pkgs.phinger-cursors;
      size = 32;
    };

    font.size = lib.mkDefault 14;

    iconTheme = {
      name = "ePapirus";
      package = pkgs.papirus-icon-theme;
    };
  };
}
