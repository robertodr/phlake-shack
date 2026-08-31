{
  pkgs,
  ...
}:
{
  programs.pi-coding-agent = {
    enable = true;
    package = pkgs.llm-agents.pi;
    context = ''
      If you make a commit, follow conventional commits and add a trailer:
      `Assisted-by: <harness>:<model>`, where `<harness>` is the current agent harness
      (like Pi), and `<model>` is the AI model (Like claude-opus-4.8). You
      don't need to add a coauthored-by when you have this.

      Prefix PR descriptions and comments on PRs with the line ":robot: _AI text
      below_ :robot:" to indicate you are an agent speaking on a user's behalf.
    '';
    extraPackages = [
      pkgs.nodejs
      pkgs.bun
    ];
    settings = {
      packages = [
        "npm:@narumitw/pi-starship"
        "npm:@termdraw/pi"
        "npm:pi-diff-review"
        "npm:pi-mcp-adapter"
      ];
      defaultModel = "gpt-5.6-sol";
      defaultProvider = "openai-codex";
      defaultThinkingLevel = "medium";
    };
  };
}
