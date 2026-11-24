{ self, pkgs }:
let
  inherit (pkgs) lib;
  linux = lib.genAttrs [ "dancer" "kellanved" ] (name: {
    inherit (self.nixosConfigurations.${name}) pkgs;
    config = self.nixosConfigurations.${name}.config.home-manager.users.roberto;
  });
  homes = linux // {
    crokus = self.homeConfigurations."robertoeikas@crokus";
  };
  managed =
    home:
    lib.mapAttrs' (_: file: lib.nameValuePair file.target file) (
      lib.filterAttrs (_: file: file.enable) home.config.home.file
    );
  checks = lib.mapAttrs (
    host: home:
    let
      inherit (home.config) programs;
      agents = home.pkgs.llm-agents;
      files = managed home;
      installed = package: builtins.elem package.outPath (map (p: p.outPath) home.config.home.packages);
      context = ../homes/profiles/agent-clis/AGENTS.md;
      checksForHome = {
        packages =
          lib.all (name: programs.${name}.enable && programs.${name}.package == agents.${name}) [
            "codex"
            "antigravity-cli"
            "claude-code"
          ]
          && lib.all installed [
            agents.rtk
            agents.codex
            agents.antigravity-cli
            programs.claude-code.finalPackage
          ]
          && !installed agents.claude-code;
        pi =
          let
            pi = agents.pi.override { useBun = false; };
          in
          programs.pi-coding-agent.enable
          && programs.pi-coding-agent.package == pi
          && lib.any (
            p: lib.getName p == "pi-wrapped" && (map toString (p.paths or [ ])) == [ pi.outPath ]
          ) home.config.home.packages
          && files ? ".pi/agent/extensions/bounded-compaction";
        common-context = lib.all (target: files.${target}.source == context && !files.${target}.force) [
          ".pi/agent/AGENTS.md"
          ".claude/CLAUDE.md"
          ".codex/AGENTS.md"
          ".gemini/AGENTS.md"
        ];
        mcp =
          programs.mcp.enable
          && programs.codex.enableMcpIntegration
          && programs.claude-code.enableMcpIntegration
          && !programs.antigravity-cli.enableMcpIntegration
          && lib.all (target: files ? ${target} && !files.${target}.force) [
            ".pi/agent/mcp.json"
            ".codex/config.toml"
            ".gemini/config/mcp_config.json"
          ];
        writable-claude-settings =
          !(files ? ".claude.json")
          && !(files ? ".claude/settings.json")
          && home.config.home.activation ? claudeCodeStatusLine;
      };
    in
    lib.mapAttrsToList (
      name: pass: lib.assertMsg pass "${host}: agent-clis ${name} failed"
    ) checksForHome
  ) homes;
in
assert lib.all lib.id (lib.concatLists (builtins.attrValues checks));
pkgs.runCommand "agent-clis" { } ''
  ${lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      host: home:
      let
        files = managed home;
      in
      ''
        echo 'Checking ${host} MCP registrations'
        ${lib.getExe pkgs.python3} ${./agent-clis-mcp.test.py} \
          ${lib.getExe home.pkgs.llm-agents.codegraph} \
          ${files.".codex/config.toml".source} \
          ${files.".gemini/config/mcp_config.json".source} \
          ${files.".pi/agent/mcp.json".source} \
          ${home.config.programs.claude-code.finalPackage}/bin/claude
      ''
    ) linux
  )}
  touch "$out"
''
