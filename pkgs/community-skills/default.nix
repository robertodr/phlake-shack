{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  installAgentSkills,
  python3,
  writeText,
  # Visibility is configuration, not a mutable edit made by /toggle-skills.
  autoInvokeSkills ? [
    "dispatching-parallel-agents"
    "subagent-driven-development"
  ],
}:
let
  sources = import ./sources.nix;
  fetched = lib.mapAttrs (
    _: source:
    fetchFromGitHub {
      inherit (source)
        owner
        repo
        rev
        hash
        ;
    }
  ) sources;
  skillSources = lib.foldlAttrs (
    result: key: source:
    result // lib.mapAttrs (_: path: "${fetched.${key}}/${path}") source.skills
  ) { } sources;
  skillNames = builtins.attrNames skillSources;
  provenance = writeText "community-skills-sources.json" (builtins.toJSON sources);
in
assert lib.assertMsg (
  lib.all (name: builtins.elem name skillNames) autoInvokeSkills
  && builtins.length (lib.unique autoInvokeSkills) == builtins.length autoInvokeSkills
) "Community skill visibility must contain unique names from the pinned allowlist";
stdenvNoCC.mkDerivation {
  pname = "community-skills";
  version = "0-unstable-2026-09-19";
  dontUnpack = true;
  dontBuild = true;
  dontInstallAgentSkills = true;
  # These are upstream instruction resources, not newly built executables.
  # Preserve scripts verbatim rather than rewriting their portable shebangs.
  dontFixup = true;
  nativeBuildInputs = [ installAgentSkills ];

  installPhase = ''
    runHook preInstall
    ${lib.concatMapStringsSep "\n" (
      name: "installSkill ${lib.escapeShellArg skillSources.${name}} ${lib.escapeShellArg name}"
    ) skillNames}
    chmod u+w "$out"/share/skills/*/*/SKILL.md
    ${lib.getExe python3} ${./visibility.py} "$out/share/skills" \
      ${lib.escapeShellArg (builtins.toJSON autoInvokeSkills)}
    ${lib.concatMapAttrsStringSep "\n" (key: _: ''
      install -Dm644 ${fetched.${key}}/LICENSE "$out/share/doc/community-skills/${key}/LICENSE"
    '') sources}
    install -Dm644 ${provenance} "$out/share/doc/community-skills/sources.json"
    runHook postInstall
  '';

  passthru = {
    inherit skillNames skillSources autoInvokeSkills;
    # Preserve the explicitly linked Claude selection from the imperative setup.
    claudeSkillNames = builtins.attrNames sources.mattpocock.skills;
  };

  meta = {
    description = "Pinned Superpowers, Matt Pocock and find-skills agent skills";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
