{
  config,
  lib,
  ...
}: {
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = lib.getExe config.programs.kitty.package;
        layer = "overlay";
        icon-theme = "Nordzy-dark";
        width = 50;
      };
    };
  };
}
