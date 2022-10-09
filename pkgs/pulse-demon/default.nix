{ stdenv
}:

stdenv.mkDerivation {
  pname = "pulse-demon-background";
  version = "1.0";

  src = ./.;

  installPhase = ''
    mkdir -p $out/share
    cp $src/*.png $out/share
  '';
}
