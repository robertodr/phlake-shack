{ self, pkgs }:
let
  inherit (pkgs) lib;
  hook = self.inputs.llm-agents.inputs.nixpkgs.legacyPackages.x86_64-linux.installAgentSkills;
  checks =
    lib.concatMap
      (
        host:
        let
          config = self.nixosConfigurations.${host}.config;
          packages = self.nixosConfigurations.${host}.pkgs;
        in
        map
          (name: {
            name = "${host}-${name}-has-agent-skills-hook";
            pass =
              let
                package =
                  if name == "herdr" then
                    config.home-manager.users.roberto.programs.herdr.package
                  else
                    packages.llm-agents.${name};
              in
              builtins.isString package.drvPath
              && lib.any (input: input.outPath == hook.outPath) package.nativeBuildInputs;
          })
          [
            "herdr"
            "qmd"
          ]
      )
      [
        "kellanved"
        "dancer"
      ];
  failed = map (check: check.name) (builtins.filter (check: !check.pass) checks);
  names = map (check: check.name) checks;
in
assert lib.assertMsg (
  failed == [ ]
) "Agent skills hook checks failed: ${lib.concatStringsSep ", " failed}";
pkgs.runCommand "agent-skills-evaluation"
  {
    passthru.report = {
      count = builtins.length names;
      passed = names;
    };
  }
  ''
    printf '%s\n' '${builtins.toJSON names}' > "$out"
  ''
