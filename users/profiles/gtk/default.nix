{pkgs, ...}: {
  gtk = {
    enable = true;
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
