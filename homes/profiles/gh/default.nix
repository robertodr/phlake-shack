{ pkgs, pkgsUnstable, ... }:
{
  programs.gh = {
    enable = true;
    extensions = [
      pkgs.gh-actions-cache
      pkgs.gh-dash
      pkgsUnstable.gh-stack
    ];
  };

  home.packages = [ pkgs.llm-agents.copilot-cli ];
}
