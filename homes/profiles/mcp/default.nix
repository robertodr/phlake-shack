{
  lib,
  pkgs,
  ...
}:
{
  programs.mcp = {
    enable = true;

    servers = {
      # Requires Paperpile beta access; authenticate with `pi mcp login paperpile`.
      paperpile.url = "https://mcp.paperpile.com/";

      # Notion's hosted MCP server uses OAuth; authenticate with `pi mcp login notion`.
      notion.url = "https://mcp.notion.com/mcp";

      codegraph = {
        command = lib.getExe pkgs.llm-agents.codegraph;
        args = [
          "serve"
          "--mcp"
        ];
      };
    };
  };
}
