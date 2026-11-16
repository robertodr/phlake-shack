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
    package = pkgs.llm-agents.pi.override {
      useBun = false;
    };
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
        "npm:@gotgenes/pi-anthropic-auth"
        "npm:@monotykamary/pi-math"
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
      compaction = {
        keepRecentTokens = 8000;
        reserveTokens = 32768;
      };
    };
  };

  # Keep mutable npm updates off the boot/login critical path. A user timer
  # retries daily, including after offline starts, without blocking activation.
  systemd.user = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    services.pi-update-extensions = {
      Unit.Description = "Update Pi extensions";
      Service = {
        Type = "oneshot";
        Environment = "PATH=${
          lib.makeBinPath (config.programs.pi-coding-agent.extraPackages ++ [ pkgs.coreutils ])
        }:/run/current-system/sw/bin";
        ExecStart = "${lib.getExe config.programs.pi-coding-agent.package} update --extensions";
        TimeoutStartSec = "5m";
      };
    };
    timers.pi-update-extensions = {
      Unit.Description = "Update Pi extensions in the background";
      Timer = {
        OnStartupSec = "5m";
        OnUnitActiveSec = "1d";
        Unit = "pi-update-extensions.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  # Reuse the shared MCP servers with Pi's built-in MCP support. Omit unset
  # optional fields: Home Manager represents them as null, which Pi rejects.
  home = {
    file = {
      "${config.programs.pi-coding-agent.configDir}/extensions/bounded-compaction".source =
        ./bounded-compaction;

      "${config.programs.pi-coding-agent.configDir}/mcp.json" = lib.mkIf config.programs.mcp.enable {
        source = jsonFormat.generate "pi-mcp.json" {
          mcpServers = lib.mapAttrs (
            _: server: lib.filterAttrs (_: value: value != null) server
          ) config.programs.mcp.servers;
        };
      };

    };

    activation = {
      # pi-starship rejects symlinks. Run after linkGeneration so Home Manager
      # has removed the previously managed link before installing a regular file.
      installPiStarship =
        let
          settings = tomlFormat.generate "pi-starship.toml" {
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
        in
        lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          run ${pkgs.coreutils}/bin/install -Dm600 ${settings} \
            ${lib.escapeShellArg "${config.programs.pi-coding-agent.configDir}/pi-starship.toml"}
        '';

      # RTK ships the Pi extension itself; keep rewrite rules in the installed RTK
      # version rather than maintaining a separate command-rewriting implementation.
      installPiRtk = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe pkgs.llm-agents.rtk} init --agent pi --global
      '';
    };
  };
}
