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

    servers.codegraph = {
      command = lib.getExe pkgs.llm-agents.codegraph;
      args = [
        "serve"
        "--mcp"
      ];
    };
  };
}
