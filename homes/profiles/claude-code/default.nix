{ pkgsUnstable, ... }:
{
  programs.claude-code = {
    enable = true;
    package = pkgsUnstable.claude-code;
  };
}
