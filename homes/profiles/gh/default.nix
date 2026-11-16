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

  programs.github-copilot-cli = {
    enable = true;
    package = pkgs.llm-agents.copilot-cli;
  };
}
