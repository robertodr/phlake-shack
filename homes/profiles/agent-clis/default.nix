{
  config,
  lib,
  pkgs,
  ...
}:
let
  context = ./AGENTS.md;
in
{
  programs = {
    pi-coding-agent = { inherit context; };
    claude-code = {
      inherit context;
      enableMcpIntegration = true;
    };
    codex = {
      enable = true;
      package = pkgs.llm-agents.codex;
      inherit context;
      enableMcpIntegration = true;
    };
    antigravity-cli = {
      enable = true;
      package = pkgs.llm-agents.antigravity-cli;
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
}
