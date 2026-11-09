{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
let
  butSkills = pkgs.callPackage ../../../pkgs/but-skills {
    but = pkgs.llm-agents.but;
    # The host's stable nixpkgs lacks this hook; use the existing unstable pin
    # only for this small skills derivation, not for rebuilding cached CLIs.
    inherit (pkgsUnstable) installAgentSkills;
  };
  skills = {
    but = "${butSkills}/share/skills/but/but";
    herdr = "${config.programs.herdr.package}/share/skills/herdr/herdr";
    qmd = "${pkgs.llm-agents.qmd}/share/skills/qmd/qmd";
  };
  destinations = [
    ".agents/skills"
    "${config.programs.claude-code.configDir}/skills"
  ];
in
{
  # Pi discovers ~/.agents/skills itself. Link the exact same allowlist for
  # Claude, without duplicating it in Pi's private directory. Whole-directory
  # links preserve references/assets and need no evaluation-time traversal
  # of package outputs (important when evaluating Darwin from Linux).
  home.file = lib.listToAttrs (
    lib.concatMap (
      directory:
      lib.mapAttrsToList (
        name: source:
        lib.nameValuePair "${directory}/${name}" {
          inherit source;
        }
      ) skills
    ) destinations
  );
}
