{}: {
  programs.fuzzel = {
    enable = true;
    # see: https://codeberg.org/dnkl/fuzzel/src/branch/master/doc/fuzzel.ini.5.scd
    settings = {
      main = {
        terminal = "${pkgs.kitty}/bin/kitty";
        layer = "overlay";
        font = "M PLUS 2 Regular";
        icon-theme = "ePapirus";
        dpi-aware = "yes";
        width = 50;
      };
    };
  };
}
