{config, lib, ...}: {
  programs.fuzzel = {
    enable = true;
    # see: https://codeberg.org/dnkl/fuzzel/src/branch/master/doc/fuzzel.ini.5.scd
    settings = {
      main = {
        terminal = lib.getExe config.programs.kitty.package;
        layer = "overlay";
        icon-theme = "Nordzy-dark";
        dpi-aware = "yes";
        width = 50;
      };
    };
  };
}
