{
  config,
  lib,
  pkgs,
  ...
}:
let
  context = ./AGENTS.md;
  codexDir = if config.home.preferXdgDirectories then "${config.xdg.configHome}/codex" else ".codex";
  codexFile = "${lib.removePrefix config.home.homeDirectory codexDir}/config.toml";
  python = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
in
{
  imports = [
    ./egm.nix
    ./rtk-hooks.nix
    ./agy-sandbox.nix
  ];

  options.profiles.agent-clis.codeMode.enable =
    lib.mkEnableOption "native experimental Code Mode for Claude and Codex";

  config = {
    home = {
      sessionVariables =
        lib.mkIf (config.profiles.agent-clis.codeMode.enable && config.programs.claude-code.enable)
          {
            CLAUDE_CODE_EXPERIMENTAL_CODE_MODE = "1";
          };

      # Retain the pinned module's generated MCP payload, not its read-only link:
      # Codex persists per-user project trust and other choices in config.toml.
      file = lib.mkIf config.programs.codex.enable { ${codexFile}.enable = false; };
      activation = lib.mkIf config.programs.codex.enable {
        codexWritableConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          run ${lib.getExe python} ${./merge-codex.py} \
            ${config.home.file.${codexFile}.source} \
            ${
              if lib.hasPrefix "/" codexDir then
                lib.escapeShellArg codexDir
              else
                ''"$HOME"/${lib.escapeShellArg codexDir}''
            }/config.toml
        '';
      };

    };

    programs = {
      pi-coding-agent = { inherit context; };
      claude-code = lib.mkIf config.programs.claude-code.enable {
        inherit context;
        enableMcpIntegration = true;
      };
      codex = lib.mkIf config.programs.codex.enable {
        settings.features.code_mode = lib.mkIf config.profiles.agent-clis.codeMode.enable true;
        package = pkgs.llm-agents.codex;
        inherit context;
        enableMcpIntegration = true;
      };
      antigravity-cli = lib.mkIf config.programs.antigravity-cli.enable {
        package = lib.mkDefault pkgs.llm-agents.antigravity-cli;
        context.AGENTS = context;
        # The pinned integration drops remote URLs. Remove this adapter only
        # after verifying that a newer pin generates correct remote entries.
        enableMcpIntegration = false;
        mcpServers = lib.mapAttrs (
          _: server:
          if server.url != null then { serverUrl = server.url; } else { inherit (server) command args; }
        ) config.programs.mcp.servers;
      };
    };
  };
}
