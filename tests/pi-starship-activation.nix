{ pkgs, self }:
let
  inherit (pkgs) lib;
  testHost =
    name:
    let
      home = self.nixosConfigurations.${name}.config.home-manager.users.roberto;
      # Derive Pi's default location independently of the activation script.
      target = ".pi/agent/pi-starship.toml";
      activation = home.home.activation.installPiStarship.data or "";
      script = lib.replaceStrings [ home.home.homeDirectory ] [ "$HOME" ] activation;
    in
    assert lib.assertMsg (
      !(home.home.file ? ${target}) && !(home.home.file ? "${home.home.homeDirectory}/${target}")
    ) "${name}: pi-starship settings must not be symlink-managed";
    assert lib.assertMsg (activation != "") "${name}: pi-starship needs a regular-file activation";
    pkgs.runCommand "pi-starship-activation-${name}" { } ''
      export HOME="$TMPDIR/home"
      target="$HOME/${target}"
      mkdir -p "$(dirname "$target")"
      printf 'old settings\n' > "$TMPDIR/old.toml"
      ln -s "$TMPDIR/old.toml" "$target"
      run() { "$@"; }
      activate() {
        ${script}
      }

      # Migrate the previous Home Manager symlink without modifying its source.
      activate
      test -f "$target" && test ! -L "$target"
      grep -F 'old settings' "$TMPDIR/old.toml"
      grep -F 'truncation_length = 36' "$target"
      grep -F '$provider' "$target"
      test "$(stat -c %a "$target")" = 600
      cp "$target" "$TMPDIR/expected.toml"

      # Reactivation restores the declarative settings as a regular file.
      printf 'local edit\n' > "$target"
      activate
      test ! -L "$target"
      cmp "$target" "$TMPDIR/expected.toml"

      # A fresh home must also work, with no pre-existing config directory.
      rm -r "$HOME"
      activate
      test -f "$target" && test ! -L "$target"
      cmp "$target" "$TMPDIR/expected.toml"
      touch "$out"
    '';
  testUpdates =
    name:
    let
      home = self.nixosConfigurations.${name}.config.home-manager.users.roberto;
      service = home.systemd.user.services.pi-update-extensions or { };
      timer = home.systemd.user.timers.pi-update-extensions or { };
    in
    assert lib.assertMsg (
      (home.home.activation.updatePiExtensions.data or "") == ""
    ) "${name}: network updates must not block Home Manager activation";
    assert lib.assertMsg (
      (timer.Install.WantedBy or [ ]) == [ "timers.target" ]
      && (timer.Timer.OnStartupSec or "") == "5m"
      && (timer.Timer.OnUnitActiveSec or "") == "1d"
      && (timer.Timer.Unit or "") == "pi-update-extensions.service"
    ) "${name}: extension updates need a delayed, recurring user timer";
    assert lib.assertMsg (
      (service.Service.Type or "") == "oneshot"
      && lib.any (lib.hasInfix "update --extensions") (lib.toList (service.Service.ExecStart or [ ]))
      && (service.Service.TimeoutStartSec or "") == "5m"
      && (service.Install.WantedBy or [ ]) == [ ]
    ) "${name}: extension update service must be bounded and timer-only";
    pkgs.runCommand "pi-extension-updates-${name}" { } "touch $out";
in
pkgs.runCommand "pi-starship-activation"
  {
    dancer = testHost "dancer";
    kellanved = testHost "kellanved";
    kellanvedUpdates = testUpdates "kellanved";
  }
  ''
    test -f "$dancer" && test -f "$kellanved"
    test -f "$kellanvedUpdates"
    touch "$out"
  ''
