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

    # TODO within stylix conf
    #font.size = lib.mkDefault 14;

    iconTheme = {
      name = "Nordzy-dark";
      package = pkgs.nordzy-icon-theme;
    };
  };
}
