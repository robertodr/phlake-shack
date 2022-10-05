{pkgs, ...}: {
  gtk = {
    enable = true;

    cursorTheme = {
      name = "phinger-cursors";
      package = pkgs.phinger-cursors;
      size = 32;
    };

    font = {
      name = "M PLUS 2 Regular";
      size = 14;
    };

    iconTheme = {
      name = "ePapirus";
      package = pkgs.papirus-icon-theme;
    };
  };
}
