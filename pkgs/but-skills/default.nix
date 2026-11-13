{
  lib,
  stdenvNoCC,
  installAgentSkills,
  but,
}:
stdenvNoCC.mkDerivation {
  pname = "but-skills";
  inherit (but) version;
  dontUnpack = true;
  dontInstallAgentSkills = true;

  nativeBuildInputs = [ installAgentSkills ];

  # The cached CLI embeds the complete, version-matched skill. Extract it in
  # the sandbox rather than rebuilding but or invoking its installer at login.
  installPhase = ''
    runHook preInstall
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    cd "$TMPDIR"
    ${lib.getExe but} skill install --path "$TMPDIR/but"
    installSkill "$TMPDIR/but" but
    runHook postInstall
  '';

  meta = {
    description = "Agent skill bundled with the GitButler CLI";
    inherit (but.meta) license platforms;
  };
}
