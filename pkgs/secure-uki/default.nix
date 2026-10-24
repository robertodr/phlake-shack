{
  lib,
  python3Packages,
  openssl,
  tpm2-tools,
  systemd,
}:
python3Packages.buildPythonApplication {
  pname = "secure-uki";
  version = "0.1.0";
  pyproject = true;
  # Retained local caches are not source inputs or deliverable code. Never delete
  # them to manufacture equality with an explicitly enumerated source archive.
  src = lib.cleanSourceWith {
    src = ./.;
    filter =
      path: type:
      lib.cleanSourceFilter path type
      && builtins.baseNameOf path != "__pycache__"
      && !lib.hasSuffix ".pyc" path;
  };
  build-system = [ python3Packages.setuptools ];
  strictDeps = true;
  # Compile binding into the installed code, not caller PATH/env configuration.
  postPatch = ''
    substituteInPlace src/secure_uki/prepare.py \
      --replace-fail 'OPENSSL = "openssl"' 'OPENSSL = "${openssl}/bin/openssl"'
    substituteInPlace src/secure_uki/parent_maintenance.py \
      --replace-fail 'TPM_TOOLS = None' 'TPM_TOOLS = "${tpm2-tools}/bin"'
    substituteInPlace src/secure_uki/enrollment_maintenance.py \
      --replace-fail 'SYSTEMD = None' 'SYSTEMD = "${systemd}"'
  '';
  passthru.tpmTools = tpm2-tools; # Immutable later-maintenance binding; issuer never calls it.
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
    "secure_uki.migration_state"
    "secure_uki.filesystem_identity"
    "secure_uki.maintenance"
    "secure_uki.policy_rotation"
    "secure_uki.tpm_parent"
    "secure_uki.parent_maintenance"
    "secure_uki.tpm_enrollment"
    "secure_uki.enrollment_maintenance"
    "secure_uki.enrollment_terminal"
    "secure_uki.cli"
    "secure_uki.fwupd"
  ];

  meta = {
    description = "Target-local signed UKI installer with recoverable publication";
    mainProgram = "secure-uki";
    platforms = [ "x86_64-linux" ];
  };
}
