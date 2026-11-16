{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
}:

let
  pname = "oleafly";
  version = "0.4.12";
  sources = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-xM8ZYKbcfEUYZn6W6QEGIwvhNt6/6tidStJ4+yLlVqc=";
    };
    aarch64-linux = {
      arch = "aarch64";
      hash = "sha256-hAOXMsDNe2Cr0cNXDMxLnm2Ju5iO3jpmGy88aC31mow=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
  src = fetchurl {
    url = "https://github.com/Oleafly/Oleafly/releases/download/v${version}/Oleafly_${version}_${source.arch}.AppImage";
    inherit (source) hash;
  };
  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm644 ${appimageContents}/Oleafly.desktop "$out/share/applications/oleafly.desktop"
    substituteInPlace "$out/share/applications/oleafly.desktop" \
      --replace-fail 'Exec=oleafly-desktop' "Exec=$out/bin/oleafly"
    cp -r ${appimageContents}/usr/share/icons "$out/share/"
  '';

  meta = {
    description = "Desktop workspace for writing research papers in LaTeX, Typst, and Markdown";
    homepage = "https://oleafly.com";
    changelog = "https://github.com/Oleafly/Oleafly/releases/tag/v${version}";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames sources;
    mainProgram = "oleafly";
  };
}
