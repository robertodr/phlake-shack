{ self, pkgs }:
let
  inherit (pkgs) lib;
  hook = self.inputs.llm-agents.inputs.nixpkgs.legacyPackages.x86_64-linux.installAgentSkills;
  communitySkills = pkgs.callPackage ../pkgs/community-skills {
    installAgentSkills = hook;
  };
  communityPlan = pkgs.writeText "community-skills-test-plan.json" (
    builtins.toJSON {
      sources = communitySkills.skillSources;
      autoInvoke = communitySkills.autoInvokeSkills;
    }
  );
  python = pkgs.python3.withPackages (packages: [ packages.pyyaml ]);
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
    "obsidian-bases"
    "obsidian-cli"
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
        gemini = files.".gemini/config/skills/${name}" or null;
        claude = files."${claudeDir}/skills/${name}" or null;
      in
      {
        name = "${host}-${name}-shared-skill";
        pass =
          shared != null
          && gemini != null
          && gemini.enable
          && gemini.source == shared.source
          && !gemini.recursive
          && !gemini.force
          && gemini.target == ".gemini/config/skills/${name}"
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
    ++
      map
        (name: {
          name = "${host}-excluded-${name}-skill";
          pass =
            !(files ? ".agents/skills/${name}")
            && !(files ? "${claudeDir}/skills/${name}")
            && !(files ? "${piDir}/skills/${name}");
        })
        [
          "knap"
          "obsidian-headless"
        ]
    ++ [
      {
        name = "${host}-exact-gemini-skill-targets";
        pass =
          let
            targets = map (file: file.target) (builtins.attrValues files);
            under = root: target: target == root || lib.hasPrefix "${root}/" target;
          in
          lib.sort builtins.lessThan (builtins.filter (under ".gemini/config/skills") targets)
          == lib.sort builtins.lessThan (map (name: ".gemini/config/skills/${name}") skillNames)
          && !(lib.any (under ".codex/skills") targets);
      }
      {
        name = "${host}-defuddle-cli-installed";
        pass = lib.any (package: lib.getName package == "defuddle") home.home.packages;
      }
      {
        name = "${host}-no-legacy-gitbutler-skill";
        pass =
          !(files ? ".agents/skills/gitbutler")
          && !(files ? "${claudeDir}/skills/gitbutler")
          && !(files ? "${piDir}/skills/gitbutler");
      }
    ]
  ) (builtins.attrNames homes);
  communityLinkChecks = lib.concatMap (
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
        forClaude = builtins.elem name communitySkills.claudeSkillNames;
      in
      {
        name = "${host}-${name}-community-skill";
        pass =
          shared != null
          && !shared.recursive
          && !shared.force
          && lib.hasSuffix "/share/skills/${name}/${name}" (toString shared.source)
          && lib.hasInfix "-community-skills-" (toString shared.source)
          && !(files ? "${piDir}/skills/${name}")
          && (
            if forClaude then
              claude != null && claude.source == shared.source && !claude.recursive && !claude.force
            else
              claude == null
          );
      }
    ) communitySkills.skillNames
  ) (builtins.attrNames homes);
  checks = hookChecks ++ linkChecks ++ communityLinkChecks;
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
    ) (skillNames ++ communitySkills.skillNames)
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
    # Verify all copied resources and bodies against the pinned upstream trees,
    # independently parse YAML metadata, and exercise visibility edge cases.
    ${lib.concatMapStringsSep "\n" (
      host:
      let
        skillsRoot = builtins.dirOf (
          builtins.dirOf (
            toString linuxHomes.${host}.home.file.".agents/skills/dispatching-parallel-agents".source
          )
        );
      in
      ''
        PYTHONDONTWRITEBYTECODE=1 ${lib.getExe python} ${./community-skills.test.py} \
          ${communityPlan} ${skillsRoot} ${../pkgs/community-skills/visibility.py}
      ''
    ) (builtins.attrNames linuxHomes)}
    # Exercise each Linux home's selected CLI on a local file, without network.
    cat > defuddle.html <<'HTML'
    <!doctype html>
    <html><head><title>Offline Defuddle fixture</title></head><body><main><article>
    <h1>Offline Defuddle fixture</h1>
    <p>This article is a local fixture for testing clean Markdown extraction.
    The input contains ordinary HTML paragraphs and needs no network access.
    Defuddle should preserve this article while removing unrelated page clutter.
    The managed executable must support the same parse and Markdown flags that
    the installed agent skill instructs Pi and Claude Code to use.</p>
    <p>This second paragraph provides additional article content for extraction.
    It is deliberately self-contained and contains no remote images, scripts,
    or stylesheets. A successful run demonstrates that the actual CLI and its
    JavaScript runtime dependencies work, rather than merely that a package is
    listed in the Home Manager configuration.</p>
    </article></main></body></html>
    HTML
    ${lib.concatMapStringsSep "\n" (
      host:
      let
        defuddle = lib.findFirst (
          package: lib.getName package == "defuddle"
        ) null linuxHomes.${host}.home.packages;
        skillsRoot = builtins.dirOf (
          builtins.dirOf (toString linuxHomes.${host}.home.file.".agents/skills/defuddle".source)
        );
      in
      ''
        ${lib.getExe defuddle} --help > /dev/null
        ${lib.getExe defuddle} parse "$PWD/defuddle.html" --md > ${host}-article.md
        grep -F 'This article is a local fixture' ${host}-article.md
        ${lib.getExe defuddle} parse "$PWD/defuddle.html" -p title | grep -F 'Offline Defuddle fixture'
        test ! -e ${skillsRoot}/knap
        test ! -e ${skillsRoot}/obsidian-headless
      ''
    ) (builtins.attrNames linuxHomes)}
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
