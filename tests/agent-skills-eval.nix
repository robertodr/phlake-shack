{ self, pkgs }:
let
  inherit (pkgs) lib;
  hook = self.inputs.llm-agents.inputs.nixpkgs.legacyPackages.x86_64-linux.installAgentSkills;
  linuxHomes = lib.genAttrs [ "kellanved" "dancer" ] (
    host: self.nixosConfigurations.${host}.config.home-manager.users.roberto
  );
  homes = linuxHomes // {
    crokus = self.homeConfigurations."robertoeikas@crokus".config;
  };
  skillNames = [
    "but"
    "herdr"
    "qmd"
    "defuddle"
    "json-canvas"
    "knap"
    "obsidian-bases"
    "obsidian-cli"
    "obsidian-headless"
    "obsidian-markdown"
  ];
  hookChecks = lib.concatMap (
    host:
    let
      packages = self.nixosConfigurations.${host}.pkgs;
    in
    map
      (name: {
        name = "${host}-${name}-has-agent-skills-hook";
        pass =
          let
            package =
              if name == "herdr" then linuxHomes.${host}.programs.herdr.package else packages.llm-agents.${name};
          in
          lib.any (input: input.outPath == hook.outPath) package.nativeBuildInputs;
      })
      [
        "herdr"
        "qmd"
      ]
  ) (builtins.attrNames linuxHomes);
  linkChecks = lib.concatMap (
    host:
    let
      home = homes.${host};
      files = home.home.file;
      claudeDir = home.programs.claude-code.configDir;
      piDir = home.programs.pi-coding-agent.configDir;
    in
    map (
      name:
      let
        shared = files.".agents/skills/${name}" or null;
        claude = files."${claudeDir}/skills/${name}" or null;
      in
      {
        name = "${host}-${name}-shared-skill";
        pass =
          shared != null
          && claude != null
          && shared.source == claude.source
          && !shared.recursive
          && !claude.recursive
          && !shared.force
          && !claude.force
          && lib.hasSuffix "/share/skills/${name}/${name}" (toString shared.source)
          && !(files ? ".pi/agent/skills/${name}")
          && !(files ? "${piDir}/skills/${name}");
      }
    ) skillNames
    ++ [
      {
        name = "${host}-no-legacy-gitbutler-skill";
        pass =
          !(files ? ".agents/skills/gitbutler")
          && !(files ? "${claudeDir}/skills/gitbutler")
          && !(files ? "${piDir}/skills/gitbutler");
      }
    ]
  ) (builtins.attrNames homes);
  checks = hookChecks ++ linkChecks;
  failed = map (check: check.name) (builtins.filter (check: !check.pass) checks);
  names = map (check: check.name) checks;
  # Only realize native packages. Darwin link evaluation above is not a native
  # Darwin build or an activation test.
  fileChecks = lib.concatMapStringsSep "\n" (
    host:
    lib.concatMapStringsSep "\n" (
      name:
      let
        source = linuxHomes.${host}.home.file.".agents/skills/${name}".source;
      in
      ''
        test -f ${lib.escapeShellArg "${source}/SKILL.md"}
        grep -Fx ${lib.escapeShellArg "name: ${name}"} ${lib.escapeShellArg "${source}/SKILL.md"}
      ''
    ) skillNames
  ) (builtins.attrNames linuxHomes);
in
assert lib.assertMsg (
  failed == [ ]
) "Agent skills checks failed: ${builtins.concatStringsSep ", " failed}";
pkgs.runCommand "agent-skills"
  {
    passthru.report = {
      count = builtins.length names;
      passed = names;
    };
  }
  ''
    ${fileChecks}
    # GitButler's supporting reference documents must survive packaging too.
    test -n "$(find ${
      linuxHomes.kellanved.home.file.".agents/skills/but".source
    }/references -type f -print -quit)"
    # Obsidian skills link to these relative reference files; keep the complete
    # directories rather than only SKILL.md.
    ${lib.concatMapStringsSep "\n" (host: ''
      test -s ${linuxHomes.${host}.home.file.".agents/skills/json-canvas".source}/references/EXAMPLES.md
      test -s ${
        linuxHomes.${host}.home.file.".agents/skills/obsidian-bases".source
      }/references/FUNCTIONS_REFERENCE.md
      for reference in CALLOUTS EMBEDS PROPERTIES; do
        test -s ${
          linuxHomes.${host}.home.file.".agents/skills/obsidian-markdown".source
        }/references/$reference.md
      done
    '') (builtins.attrNames linuxHomes)}
    printf '%s\n' '${builtins.toJSON names}' > "$out"
  ''
