{
  stdenv,
  pkgs,
}:
stdenv.mkDerivation {
  pname = "pulse-demon-background";
  version = "1.0";

  src = ./.;

  nativeBuildInputs = [pkgs.imagemagick];

  installPhase = ''
    mkdir -p $out/share
    cp $src/pulse-demon.png $out/share
    # motion blur
    ${pkgs.imagemagick}/bin/convert $src/pulse-demon.png -motion-blur 0x5+1.5 $out/share/blur-pulse-demon.png
    # motion blur and flop
    ${pkgs.imagemagick}/bin/convert $src/pulse-demon.png -motion-blur 0x5+0.5 -flop $out/share/flop-blur-pulse-demon.png
  '';
}
