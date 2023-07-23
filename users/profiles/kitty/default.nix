{
  pkgs,
  lib,
  ...
}: {
  programs.kitty = {
    enable = true;
    font.size = lib.mkDefault 14;
  };
}
