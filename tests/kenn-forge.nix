{ pkgs, kellanved }:
let
  home = kellanved.config.home-manager.users.roberto;
  service = home.systemd.user.services.kenn-forge.Service;
  commands = pkgs.lib.toList service.ExecStart;
  command = builtins.head commands;
in
assert pkgs.lib.assertMsg (
  service.Type == "simple" && builtins.length commands == 1 && pkgs.lib.hasSuffix " serve" command
) "kenn-forge must run the foreground server under systemd";
pkgs.runCommand "kenn-forge-service-check"
  {
    nativeBuildInputs = [ pkgs.curl ];
  }
  ''
    export HOME="$TMPDIR/home"
    export KENN_FORGE_HOME="$HOME/.kenn/forge"
    mkdir -p "$HOME"
    printf 'data_dir = "%s/data"\n[mcp]\nenabled = false\n' "$TMPDIR" > "$TMPDIR/config.toml"

    # Exercise the actual service command without credentials or provider sync.
    ${command} --config "$TMPDIR/config.toml" --disable-sync \
      --host 127.0.0.1 --port 18091 > "$TMPDIR/server.log" 2>&1 &
    pid=$!
    trap 'kill "$pid" 2>/dev/null || true' EXIT

    ready=false
    for attempt in $(seq 1 100); do
      if curl --fail --silent http://127.0.0.1:18091/ > "$TMPDIR/index.html"; then
        ready=true
        break
      fi
      if ! kill -0 "$pid" 2>/dev/null; then
        break
      fi
      sleep 0.1
    done
    if [ "$ready" != true ]; then
      cat "$TMPDIR/server.log" >&2
      exit 1
    fi
    grep -qi '<!doctype html' "$TMPDIR/index.html"
    kill -0 "$pid"
    touch "$out"
  ''
