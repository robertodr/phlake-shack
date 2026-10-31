{
  pkgs,
  dancer,
  kellanved,
}:
let
  inherit (pkgs) lib;
  settings = dancer.config.home-manager.users.roberto.programs.starship.settings;
  framework = kellanved.config.home-manager.users.roberto.programs.starship.settings;
  battery = settings.battery or { };
  display = battery.display or [ ];
  check = name: pass: { inherit name pass; };
  checks = [
    (check "Dancer-prompt-includes-enabled-battery" (
      lib.hasInfix "$battery" settings.format && !(battery.disabled or false)
    ))
    (check "Dancer-battery-visible-through-full-charge" (lib.any (item: item.threshold >= 100) display))
    (check "Dancer-battery-colors-follow-charge-level" (
      display == [
        {
          threshold = 10;
          style = "bold red";
        }
        {
          threshold = 30;
          style = "bold yellow";
        }
        {
          threshold = 100;
          style = "bold cyan";
        }
      ]
    ))
    (check "battery-customization-is-Dancer-only" (
      !(lib.hasInfix "$battery" framework.format) && !(framework ? battery)
    ))
  ];
  failed = map (item: item.name) (builtins.filter (item: !item.pass) checks);
  names = map (item: item.name) checks;
in
assert lib.assertMsg (
  failed == [ ]
) "Starship battery checks failed: ${lib.concatStringsSep ", " failed}";
pkgs.runCommand "starship-battery-evaluation"
  {
    passthru.report = {
      count = builtins.length names;
      passed = names;
      scope = "EVALUATED_HOST_SETTINGS_NOT_LIVE_BATTERY_PROOF";
    };
  }
  ''
    printf '%s\n' '${builtins.toJSON names}' > "$out"
  ''
