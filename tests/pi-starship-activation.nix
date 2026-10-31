{ pkgs, self }:
let
  inherit (pkgs) lib;
  testHost =
    name:
    let
      home = self.nixosConfigurations.${name}.config.home-manager.users.roberto;
      target = "${home.programs.pi-coding-agent.configDir}/pi-starship.toml";
      activation = home.home.activation.installPiStarship.data or "";
      script =
        lib.replaceStrings
          [ (lib.escapeShellArg "${home.home.homeDirectory}/${target}") ]
          [ "\"$HOME/${target}\"" ]
          activation;
    in
    assert lib.assertMsg (
      !(home.home.file ? ${target})
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
in
pkgs.runCommand "pi-starship-activation"
  {
    dancer = testHost "dancer";
    kellanved = testHost "kellanved";
  }
  ''
    test -f "$dancer" && test -f "$kellanved"
    touch "$out"
  ''
