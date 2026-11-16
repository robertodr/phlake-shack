{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
}:
let
  revision = "72d06f52a2482885d9a64bd24b291c6e8628942c";
  skillNames = [
    "egm-brainstorm"
    "egm-draft"
    "egm-review"
    "egm-review-loop"
    "egm-resolve"
    "egm-bootstrap"
    "egm-drift-report"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "pi-egm";
  version = "0.1.1-${builtins.substring 0 7 revision}";
  src = fetchFromGitHub {
    owner = "google";
    repo = "elephant-goldfish-model";
    rev = revision;
    hash = "sha256-IIMahNXavG94jdYHRM8TifjEvpE0EQpAvkpTIvqOKuY=";
  };
  nativeBuildInputs = [ python3 ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/pi-egm"
    cp -r skills agents resources docs assets README.md LICENSE plugin.json "$out/share/pi-egm/"
    cp -r ${../../homes/profiles/pi-coding-agent/egm} "$out/share/pi-egm/adapter"
    cp ${../../homes/profiles/pi-coding-agent/egm/package.json} "$out/share/pi-egm/package.json"
    python3 ${./profiles.py} "$out/share/pi-egm"
    printf '%s\n' '${revision}' > "$out/share/pi-egm/REVISION"
    runHook postInstall
  '';
  passthru = { inherit revision skillNames; };
  meta = {
    description = "Experimental Pi adapter for the Elephant-Goldfish document workflow";
    homepage = "https://github.com/google/elephant-goldfish-model";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
