{
  lib,
  pkgs,
  ...
}:
{
  programs.mcp = {
    enable = true;

    servers.codegraph = {
      command = lib.getExe pkgs.llm-agents.codegraph;
      args = [
        "serve"
        "--mcp"
      ];
    };
  };
}
