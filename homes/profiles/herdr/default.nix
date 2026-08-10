{ pkgsUnstable, ... }:
{
  programs.herdr = {
    enable = true;
    package = pkgsUnstable.herdr;
    settings = {
      onboarding = false;
      keys.prefix = "ctrl+b";
      # theme/ui/terminal keys: https://herdr.dev/docs/configuration/
    };
  };
}
