{
  config,
  lib,
  pkgs,
  ...
}:
let
  rtk = lib.getExe pkgs.llm-agents.rtk;
  codexHome = config.home.sessionVariables.CODEX_HOME or "${config.home.homeDirectory}/.codex";
  # The pinned HM Codex module relocates config.toml only in XDG mode.
  codexConfigHome =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex"
    else
      "${config.home.homeDirectory}/.codex";
  plugin = ".gemini/config/plugins/rtk";
  hook = client: {
    type = "command";
    command = "${rtk} hook ${client}";
  };
in
{
  options.profiles.agent-clis.rtkHooks.enable =
    lib.mkEnableOption "RTK hooks for Codex, Claude and Antigravity (requires permission and collision preflights)";

  config = lib.mkIf config.profiles.agent-clis.rtkHooks.enable {
    assertions = lib.optional config.programs.codex.enable {
      assertion = codexHome == codexConfigHome;
      message = "RTK: CODEX_HOME must match Home Manager's Codex config.toml directory";
    };
    home.file = lib.mkMerge [
      (lib.mkIf config.programs.codex.enable {
        "${codexHome}/hooks.json".text = builtins.toJSON {
          hooks.PreToolUse = [
            {
              matcher = "Bash";
              hooks = [ (hook "codex") ];
            }
          ];
        };
      })
      (lib.mkIf config.programs.antigravity-cli.enable {
        "${plugin}/plugin.json".text = builtins.toJSON {
          name = "rtk";
          version = "1.0.0";
          description = "Antigravity plugin for transparent command rewriting and token optimization using rtk";
        };
        "${plugin}/hooks.json".text = builtins.toJSON {
          rtk-rewrite = {
            enabled = true;
            PreToolUse = [
              {
                matcher = "run_command";
                hooks = [ (hook "antigravity" // { timeout = 10; }) ];
              }
            ];
          };
        };
        "${plugin}/rules/AGENTS.md".source = ./rtk-antigravity-rules.md;
      })
    ];
  };
}
