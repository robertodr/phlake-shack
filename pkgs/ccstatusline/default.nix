{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs,
  makeWrapper,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ccstatusline";
  version = "2.2.27";

  src = fetchurl {
    url = "https://registry.npmjs.org/ccstatusline/-/ccstatusline-${finalAttrs.version}.tgz";
    hash = "sha512-8SqNdSuIaMsrefn4dCrSlBEZ7kE8UZMMa8iy4iv4OMl1INnEtmqzCYMwo7/hzmNrOVC+esFSiCj+T0pUS9HrLQ==";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/ccstatusline
    cp -r dist $out/lib/ccstatusline/
    makeWrapper ${lib.getExe nodejs} $out/bin/ccstatusline \
      --add-flags $out/lib/ccstatusline/dist/ccstatusline.js
    runHook postInstall
  '';

  meta = {
    description = "Customizable status line formatter for Claude Code";
    homepage = "https://github.com/sirmalloc/ccstatusline";
    license = lib.licenses.mit;
    mainProgram = "ccstatusline";
  };
})
