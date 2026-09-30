{
  config,
  lib,
  pkgs,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
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
      pkgs.llm-agents.rtk
      pkgs.llm-agents.codegraph
    ];
    settings = {
      defaultTools = [ "+codemode" ];
      packages = [
        "npm:@narumitw/pi-starship"
        "npm:@termdraw/pi"
        "npm:pi-diff-review"
        "npm:pi-subagents"
        "npm:pi-toggle-skills"
        "npm:pi-web-access"
      ];
      defaultModel = "gpt-6.1-sol";
      defaultProvider = "openai-codex";
      defaultThinkingLevel = "medium";
    };
  };

  # Reuse the shared MCP servers with Pi's built-in MCP support. Omit unset
  # optional fields: Home Manager represents them as null, which Pi rejects.
  home.file."${config.programs.pi-coding-agent.configDir}/mcp.json" =
    lib.mkIf config.programs.mcp.enable
      {
        source = jsonFormat.generate "pi-mcp.json" {
          mcpServers = lib.mapAttrs (_: server: lib.filterAttrs (_: value: value != null) server) (
            config.programs.mcp.servers
          );
        };
      };

  # RTK ships the Pi extension itself; keep rewrite rules in the installed RTK
  # version rather than maintaining a separate command-rewriting implementation.
  home.activation.installPiRtk = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe pkgs.llm-agents.rtk} init --agent pi --global
  '';

  # Pi packages live in mutable npm state outside the Nix store. Refresh them
  # after settings.json has been linked, but keep offline activations usable.
  home.activation.updatePiExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! run env PATH=${lib.makeBinPath config.programs.pi-coding-agent.extraPackages}:$PATH \
      ${lib.getExe config.programs.pi-coding-agent.package} update --extensions
    then
      echo "warning: could not update Pi extensions; keeping installed versions" >&2
    fi
  '';

  home.file."${config.programs.pi-coding-agent.configDir}/pi-starship.toml".source =
    tomlFormat.generate "pi-starship.toml"
      {
        format = "$brand$turn$activity$context$tokens$cost$time$provider$model$thinking$directory$git_branch$git_status";

        provider.format = "[ $provider ]($style)";

        model = {
          format = "[ $model ]($style)";
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
              hidden = false;
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
