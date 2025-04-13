{ pkgs, ... }:
{
  programs.yazi.enable = true;

  home.packages = [ pkgs.exiftool ];
}
