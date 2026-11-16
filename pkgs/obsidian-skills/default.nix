{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  installAgentSkills,
}:
let
  # Explicit allowlist: new upstream skills require review before activation.
  skillNames = [
    "defuddle"
    "json-canvas"
    "obsidian-bases"
    "obsidian-cli"
    "obsidian-markdown"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "obsidian-skills";
  version = "0-unstable-2026-11-11";

  src = fetchFromGitHub {
    owner = "obsidianmd";
    repo = "obsidian-skills";
    rev = "398127736bd4ba42d767b1419fee1a927508370b";
    hash = "sha256-+BUNxlcper8xFl0Kuxfe30crKhtrzBiDCiC8sr2IRcM=";
  };

  nativeBuildInputs = [ installAgentSkills ];
  dontBuild = true;
  dontInstallAgentSkills = true;

  installPhase = ''
    runHook preInstall
    ${lib.concatMapStringsSep "\n" (name: ''
      installSkill "plugins/obsidian/skills/${name}" ${lib.escapeShellArg name}
    '') skillNames}
    install -Dm644 LICENSE "$out/share/doc/obsidian-skills/LICENSE"
    runHook postInstall
  '';

  passthru = { inherit skillNames; };

  meta = {
    description = "Official Obsidian agent skills and supporting references";
    homepage = "https://github.com/obsidianmd/obsidian-skills";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
