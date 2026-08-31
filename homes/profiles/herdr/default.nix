{ lib, pkgs, ... }:
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

  # Herdr owns and updates the generated Pi extension. Running this on every
  # activation makes the imperative installer part of the desired HM state and
  # also refreshes the extension when Herdr changes its integration version.
  home.activation.installHerdrPiIntegration = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe pkgs.llm-agents.herdr} integration install pi
  '';
}
