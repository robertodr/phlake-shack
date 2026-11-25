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
  obsidianSkills = pkgs.callPackage ../../../pkgs/obsidian-skills {
    inherit (pkgsUnstable) installAgentSkills;
  };
  communitySkills = pkgs.callPackage ../../../pkgs/community-skills {
    inherit (pkgsUnstable) installAgentSkills;
  };
  communitySources = lib.genAttrs communitySkills.skillNames (
    name: "${communitySkills}/share/skills/${name}/${name}"
  );
  commonSkills = {
    but = "${butSkills}/share/skills/but/but";
    herdr = "${config.programs.herdr.package}/share/skills/herdr/herdr";
    qmd = "${pkgs.llm-agents.qmd}/share/skills/qmd/qmd";
  }
  // lib.genAttrs obsidianSkills.skillNames (name: "${obsidianSkills}/share/skills/${name}/${name}");
  destinations = {
    ".agents/skills" = commonSkills // communitySources;
  }
  // lib.optionalAttrs config.programs.antigravity-cli.enable {
    # Start with skills backed by the shared CLI packages; community skill
    # dependencies have not yet been verified on Antigravity.
    ".gemini/config/skills" = commonSkills;
  }
  // lib.optionalAttrs config.programs.claude-code.enable {
    "${config.programs.claude-code.configDir}/skills" =
      commonSkills // lib.getAttrs communitySkills.claudeSkillNames communitySources;
  };
in
{
  # The Defuddle skill invokes this CLI; keep it declarative rather than using npm.
  home.packages = [ pkgs.defuddle ];

  # Pi discovers ~/.agents/skills itself, without Pi-private duplicate links.
  # Keep the common skills shared and preserve the migrated Claude selection.
  # Whole-directory links retain resources without evaluation-time traversal
  # of package outputs (important when evaluating Darwin from Linux).
  home.file = lib.listToAttrs (
    lib.concatLists (
      lib.mapAttrsToList (
        directory: skills:
        lib.mapAttrsToList (
          name: source:
          lib.nameValuePair "${directory}/${name}" {
            inherit source;
          }
        ) skills
      ) destinations
    )
  );
}
