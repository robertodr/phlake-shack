{ pkgs, ... }:

{
  printing = {
    enable = true;
    drivers = [ pkgs.gutenprint pkgs.gutenprintBin ];
  };
}
