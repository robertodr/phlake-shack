{ pkgs, ... }:
{
  programs.herdr = {
    enable = true;
    package = pkgs.llm-agents.herdr;
    settings = {
      onboarding = false;
      keys.prefix = "ctrl+b";
      # theme/ui/terminal keys: https://herdr.dev/docs/configuration/
    };
  };
}
