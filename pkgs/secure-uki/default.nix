{ lib, python3Packages }:
python3Packages.buildPythonApplication {
  pname = "secure-uki";
  version = "0.1.0";
  pyproject = true;
  src = lib.cleanSource ./.;
  build-system = [ python3Packages.setuptools ];
  strictDeps = true;

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=src \
      ${python3Packages.python.interpreter} -m unittest discover -s tests -v
    # The pinned Python builder maps checkPhase to installCheckPhase.
    if output=$("$out/bin/secure-uki" install /nonexistent-system 2>&1); then
      echo "Unfinished secure-uki CLI incorrectly reported success" >&2
      exit 1
    fi
    printf '%s\n' "$output" | grep -F 'installation is disabled'
    runHook postCheck
  '';
  pythonImportsCheck = [ "secure_uki.metadata" ];

  meta = {
    description = "Target-local signed UKI installer primitives (publication disabled)";
    mainProgram = "secure-uki";
    platforms = [ "x86_64-linux" ];
  };
}
