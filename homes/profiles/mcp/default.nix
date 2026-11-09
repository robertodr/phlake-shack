{
  lib,
  pkgs,
  ...
}:
{
  programs.mcp = {
    enable = true;

    # Requires Paperpile beta access; authenticate with `pi mcp login paperpile`.
    servers.paperpile.url = "https://mcp.paperpile.com/";

    # Notion's hosted MCP server uses OAuth; authenticate with `pi mcp login notion`.
    servers.notion.url = "https://mcp.notion.com/mcp";

    servers.codegraph = {
      command = lib.getExe pkgs.llm-agents.codegraph;
      args = [
        "serve"
        "--mcp"
      ];
    };
  };
}
