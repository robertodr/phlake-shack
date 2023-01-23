{
  lib,
  pkgs,
  ...
}: {
  programs.obs-studio = {
    enable = true;
    plugins = lib.attrVals ["wlrobs"] pkgs.obs-studio-plugins;
  };
}
