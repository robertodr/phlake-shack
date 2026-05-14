{ ... }:
let
  algorithmiq = name: {
    owner = "algorithmiq";
    inherit name;
  };
in
{
  services.middleman = {
    enable = true;
    environmentFile = "/run/secrets/middleman/env";
    settings = {
      sync_budget_per_hour = 0;
      sync_interval = "15m";

      repos = map algorithmiq [
        "aurora-utils"
        "aurora-measurement"
        "aurora-state"
        "yaqs"
        "tinite"
        "tem-qiskit-function"
        "aurora-qiskit-function"
      ];

      terminal = {
        font_family = "'JuliaMono', 'Fira Code Retina', Consolas, 'Courier New', monospace";
        renderer = "ghostty-web";
      };

      agents = [
        {
          key = "aider";
          label = "aider";
          command = [ "aider" ];
          enabled = false;
        }
        {
          key = "claude";
          label = "Claude";
          command = [ "claude" ];
          enabled = false;
        }
        {
          key = "codex";
          label = "Codex";
          command = [ "codex" ];
          enabled = false;
        }
        {
          key = "gemini";
          label = "Gemini";
          command = [ "gemini" ];
          enabled = false;
        }
        {
          key = "opencode";
          label = "opencode";
          command = [ "opencode" ];
          enabled = false;
        }
      ];

      tmux = {
        agent_sessions = true;
      };
    };
  };
}
