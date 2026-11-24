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
      codex = host != "crokus";
      antigravity = host != "crokus";
      claude = host != "dancer";
      noTree =
        root:
        !lib.any (target: target == root || lib.hasPrefix "${root}/" target) (builtins.attrNames files);
      checksForHome = {
        packages =
          installed agents.rtk
          && !installed agents.claude-code
          && programs.codex.enable == codex
          && (!codex || programs.codex.package == agents.codex)
          && installed agents.codex == codex
          && programs.antigravity-cli.enable == antigravity
          && !installed agents.antigravity-cli
          && (!antigravity || installed programs.antigravity-cli.package)
          && (home.config.home.activation ? agySandboxRuntime) == antigravity
          && programs.claude-code.enable == claude
          && (
            if claude then
              programs.claude-code.package == agents.claude-code && installed programs.claude-code.finalPackage
            else
              !lib.any (p: lib.getName p == "claude-code") home.config.home.packages
          );
        egm-canary =
          let
            canary = host == "kellanved";
          in
          (files ? ".gemini/config/plugins/egm") == canary
          && (files ? ".codex/plugins/cache/egm") == canary
          && (files ? ".codex/marketplaces/egm") == canary
          && (!canary || programs.claude-code.plugins == [ files.".gemini/config/plugins/egm".source ]);
        disabled-files =
          (codex || noTree ".codex")
          && (antigravity || noTree ".gemini")
          && (claude || (noTree ".claude" && noTree ".config/ccstatusline"));
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
        common-context = lib.all (target: files.${target}.source == context && !files.${target}.force) (
          [ ".pi/agent/AGENTS.md" ]
          ++ lib.optional claude ".claude/CLAUDE.md"
          ++ lib.optional codex ".codex/AGENTS.md"
          ++ lib.optional antigravity ".gemini/AGENTS.md"
        );
        mcp =
          programs.mcp.enable
          && programs.codex.enableMcpIntegration == codex
          && programs.claude-code.enableMcpIntegration == claude
          && !programs.antigravity-cli.enableMcpIntegration
          && (antigravity || programs.antigravity-cli.mcpServers == { })
          && lib.all (target: files ? ${target} && !files.${target}.force) (
            [ ".pi/agent/mcp.json" ] ++ lib.optional antigravity ".gemini/config/mcp_config.json"
          );
        writable-codex-settings =
          !(files ? ".codex/config.toml") && (home.config.home.activation ? codexWritableConfig) == codex;
        writable-claude-settings =
          !(files ? ".claude.json")
          && !(files ? ".claude/settings.json")
          && (home.config.home.activation ? claudeCodeStatusLine) == claude
          && (files ? ".config/ccstatusline/settings.json") == claude;
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
        export HOME="$TMPDIR/${host}"
        export CODEX_HOME="$HOME/.codex"
        mkdir -p "$CODEX_HOME"
        merge() { ${home.config.home.activation.codexWritableConfig.data} }
        run() { :; }
        merge
        test ! -e "$CODEX_HOME/config.toml"
        run() { "$@"; }
        merge
        test ! -L "$CODEX_HOME/config.toml"
        test "$(stat -c %a "$CODEX_HOME/config.toml")" = 600
        ${lib.getExe home.pkgs.llm-agents.codex} mcp add local-test -- true
        printf '\n[projects."/scratch/example"]\ntrust_level = "untrusted"\n' >> "$CODEX_HOME/config.toml"
        cp "$CODEX_HOME/config.toml" before
        merge
        cmp before "$CODEX_HOME/config.toml"
        ${lib.optionalString (host == "kellanved") ''
          mkdir -p "$CODEX_HOME/marketplaces" "$CODEX_HOME/plugins/cache" "$HOME/.gemini/config/plugins"
          bundle=${files.".codex/marketplaces/egm".source}
          ln -s "$bundle" "$CODEX_HOME/marketplaces/egm"
          ln -s ${files.".codex/plugins/cache/egm".source} "$CODEX_HOME/plugins/cache/egm"
          ln -s ${files.".gemini/config/plugins/egm".source} "$HOME/.gemini/config/plugins/egm"
          # Relocate the absolute marketplace path from the real home to this fixture.
          sed -i "s|${home.config.home.homeDirectory}/.codex/marketplaces/egm|$CODEX_HOME/marketplaces/egm|g" "$CODEX_HOME/config.toml"
          ${lib.getExe home.pkgs.llm-agents.codex} plugin list --json --marketplace egm | ${lib.getExe pkgs.jq} -e '
            .installed | length == 1 and .[0].pluginId == "egm@egm" and .[0].enabled and .[0].marketplaceSource.sourceType == "local"'
          test "$(realpath "$CODEX_HOME/plugins/cache/egm/egm/0.1.1/agents/codebase_details.md")" = "$bundle/agents/codebase_details.md"
          ${home.config.programs.antigravity-cli.package}/bin/agy plugin list --json | ${lib.getExe pkgs.jq} -e '
            map(select(.name == "egm" and .enabled)) | length == 1 and (.[0].agents | index("egm-codebase-details") != null)'
        ''}
        ${lib.getExe pkgs.python3} ${./agent-clis-mcp.test.py} \
          ${lib.getExe home.pkgs.llm-agents.codegraph} \
          ${home.config.home.file.".codex/config.toml".source} \
          ${files.".gemini/config/mcp_config.json".source} \
          ${files.".pi/agent/mcp.json".source} \
          ${lib.optionalString home.config.programs.claude-code.enable "${home.config.programs.claude-code.finalPackage}/bin/claude"}
      ''
    ) linux
  )}
  touch "$out"
''
