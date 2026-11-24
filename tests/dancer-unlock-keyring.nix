{ pkgs, dancer }:
let
  helper = pkgs.lib.findFirst (
    p: p.name == "unlock-keyring"
  ) (throw "Dancer is missing unlock-keyring") dancer.config.home-manager.users.roberto.home.packages;
in
pkgs.runCommand "dancer-unlock-keyring-test"
  {
    nativeBuildInputs = [
      helper
      pkgs.dbus
      pkgs.fish
      dancer.pkgs.gnome-keyring
      pkgs.libsecret
      pkgs.python3
      pkgs.systemd
    ];
  }
  ''
    export HOME="$TMPDIR/home" XDG_DATA_HOME="$TMPDIR/home/.local/share"
    unset GNOME_KEYRING_CONTROL
    mkdir -m 700 "$HOME" "$TMPDIR/first" "$TMPDIR/second"
    # A sandbox has no /etc/dbus-1/session.conf. Do not load host services.
    cat > session.conf <<'EOF'
    <busconfig>
      <type>session</type>
      <listen>unix:tmpdir=/tmp</listen>
      <auth>EXTERNAL</auth>
      <policy context="default">
        <allow send_destination="*"/>
        <allow receive_sender="*"/>
        <allow own="*"/>
      </policy>
    </busconfig>
    EOF
    XDG_RUNTIME_DIR="$TMPDIR/first" dbus-run-session --config-file=session.conf -- python3 ${./dancer-unlock-keyring.py} create
    XDG_RUNTIME_DIR="$TMPDIR/second" dbus-run-session --config-file=session.conf -- python3 ${./dancer-unlock-keyring.py} unlock
    touch "$out"
  ''
