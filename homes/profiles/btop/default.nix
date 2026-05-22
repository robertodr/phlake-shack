{ pkgsUnstable, ... }:
{
  programs.btop = {
    enable = true;
    package = pkgsUnstable.btop;
  };
}
