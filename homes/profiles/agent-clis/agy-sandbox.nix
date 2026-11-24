{
  config,
  lib,
  pkgs,
  ...
}:
let
  agy = pkgs.llm-agents.antigravity-cli;
  tools = [
    pkgs.bashInteractive
    pkgs.git
    pkgs.llm-agents.rtk
  ];
  # Derive the small ELF runtime set, not the entire Git closure or /nix/store.
  # Include both the RPATH target and its resolved output (notably libgcc).
  rules = pkgs.runCommand "agy-sandbox-runtime-rules.json" { } ''
    set -euo pipefail
    export LC_ALL=C
    for bin in ${lib.getExe agy} ${pkgs.bashInteractive}/bin/bash ${lib.getExe pkgs.git} ${lib.getExe pkgs.llm-agents.rtk}; do
      echo "$bin"
      ${pkgs.glibc.bin}/bin/ldd "$bin" | awk '{for (i=1; i<=NF; i++) if ($i ~ /^\//) print $i; if ($0 ~ /not found/) exit 1}'
    done | while read -r file; do
      echo "$file"
      realpath -e "$file"
    done | cut -d/ -f1-4 | sort -u | ${lib.getExe pkgs.jq} -Rn '[inputs | "read_file(" + . + ")"]' > "$out"
  '';
in
{
  config = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && config.programs.antigravity-cli.enable) {
    programs.antigravity-cli.package = pkgs.writeShellScriptBin "agy" ''
      export PATH=${lib.makeBinPath tools}:"$PATH"
      exec ${lib.getExe agy} "$@"
    '';
    home.activation.agySandboxRuntime = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe pkgs.python3} ${./merge-agy-runtime.py} ${rules} \
        "$HOME/.gemini/antigravity-cli/settings.json" \
        ${lib.escapeShellArg "${config.xdg.stateHome}/agy-sandbox/managed-rules.json"}
    '';
  };
}
