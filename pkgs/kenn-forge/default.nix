{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "kenn-forge";
  version = "0.5.1";

  # Update the version and release archive hash together.
  src = fetchurl {
    url = "https://github.com/kenn-io/forge/releases/download/v${finalAttrs.version}/forge_${finalAttrs.version}_linux_amd64.tar.gz";
    hash = "sha256-x2uExZjUtA8l0nxDuIFbBoe0pSgKdmaG1VwQ1fomj7o=";
  };

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 kenn-forge "$out/bin/kenn-forge"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/kenn-forge" version | grep -F "kenn-forge v${finalAttrs.version} "
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "Local-first maintainer console with built-in agent workspaces for GitHub, GitLab, Forgejo, and Gitea";
    homepage = "https://github.com/kenn-io/forge";
    license = licenses.elastic20;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "kenn-forge";
  };
})
