{ pkgsUnstable, ... }:
{
  programs.opencode = {
    enable = true;
    package = pkgsUnstable.opencode;
  };
}
