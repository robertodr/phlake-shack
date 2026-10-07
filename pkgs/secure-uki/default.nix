{
  lib,
  python3Packages,
  openssl,
}:
python3Packages.buildPythonApplication {
  pname = "secure-uki";
  version = "0.1.0";
  pyproject = true;
  src = lib.cleanSource ./.;
  build-system = [ python3Packages.setuptools ];
  strictDeps = true;
  nativeCheckInputs = [ openssl ];
  # All other signing tools use absolute Tools paths; OpenSSL is pinned here.
  makeWrapperArgs = [
    "--set"
    "PATH"
    (lib.makeBinPath [ openssl ])
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=src \
      ${python3Packages.python.interpreter} -m unittest discover -s tests -v
    # The pinned Python builder maps checkPhase to installCheckPhase.
    if output=$("$out/bin/secure-uki" install /nonexistent-system 2>&1); then
      echo "Unprivileged secure-uki CLI incorrectly reported success" >&2
      exit 1
    fi
    printf '%s\n' "$output" | grep -F 'root is required'
    if output=$("$out/bin/secure-uki-fwupd" /nonexistent-helper 2>&1); then
      echo "Unprivileged helper signer incorrectly reported success" >&2
      exit 1
    fi
    printf '%s\n' "$output" | grep -F 'root is required'
    runHook postCheck
  '';
  pythonImportsCheck = [
    "secure_uki.metadata"
    "secure_uki.prepare"
    "secure_uki.publish"
    "secure_uki.cli"
    "secure_uki.fwupd"
  ];

  meta = {
    description = "Target-local signed UKI installer with recoverable publication";
    mainProgram = "secure-uki";
    platforms = [ "x86_64-linux" ];
  };
}
