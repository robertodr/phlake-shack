{
  config,
  pkgs,
  ...
}:
let
  tomlFormat = pkgs.formats.toml { };
in
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

  home.file."${config.programs.pi-coding-agent.configDir}/pi-starship.toml".source =
    tomlFormat.generate "pi-starship.toml"
      {
        format = "$brand$model$thinking$directory$git_branch$git_status$activity$context$time";

        model = {
          format = "[ $symbol$model ]($style)";
          symbol = "◆ ";
          style = "bold blue";
          truncation_length = 36;
          truncation_symbol = "…";
          truncation_direction = "middle";
        };

        directory.style = "cyan bold";
        git_branch.style = "bold purple";

        context = {
          format = "[$symbol $percentage/$window ]($style)";
          display = [
            {
              threshold = 0;
              style = "bold green";
              hidden = true;
            }
            {
              threshold = 30;
              style = "bold green";
              hidden = false;
            }
            {
              threshold = 60;
              style = "bold yellow";
              hidden = false;
            }
            {
              threshold = 80;
              style = "bold red";
              hidden = false;
            }
          ];
        };

        git_metrics = {
          added_style = "bold green";
          deleted_style = "bold red";
          disabled = false;
        };

        username = {
          style_user = "yellow bold";
          style_root = "red bold";
        };

        extension_status = {
          format = "([$statuses ]($style))";
          icons = {
            "foo:*" = "🧪";
            "third_party/key" = "◎";
            fallback = "•";
          };
        };
      };
}
