{
  pkgs,
  lib,
  ...
}: {
  gtk = {
    enable = true;

    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 64;
    };

    font.size = lib.mkDefault 14;

    iconTheme = {
      name = "ePapirus";
      package = pkgs.papirus-icon-theme;
    };
  };
}
