{ self, pkgs }:
let
  inherit (pkgs) lib;
  linuxHomes = lib.genAttrs [ "kellanved" "dancer" ] (
    host: self.nixosConfigurations.${host}.config.home-manager.users.roberto
  );
  # Crokus is introduced by a separate PR; validate it when present without
  # making the standalone EGM branch depend on that Home Manager target.
  homes =
    linuxHomes
    // lib.optionalAttrs (self ? homeConfigurations."robertoeikas@crokus") {
      crokus = self.homeConfigurations."robertoeikas@crokus".config;
    };
  validHome =
    home:
    let
      cfg = home.programs.pi-coding-agent;
      link = home.home.file."${cfg.configDir}/egm";
    in
    cfg.package.version == "1.5.2"
    && lib.elem (toString link.source) cfg.settings.packages
    && lib.hasSuffix "/share/pi-egm" (toString link.source)
    && !link.recursive
    && !link.force
    && !(home.home.file ? ".agents/skills/egm-review")
    && !(home.home.file ? "${home.programs.claude-code.configDir}/skills/egm-review");
  pi = linuxHomes.kellanved.programs.pi-coding-agent.package;
  bundle =
    linuxHomes.kellanved.home.file."${linuxHomes.kellanved.programs.pi-coding-agent.configDir}/egm".source;
in
assert lib.assertMsg (lib.all validHome (
  builtins.attrValues homes
)) "EGM must remain a Pi-only intact package with the audited Pi on every configured host";
pkgs.runCommand "pi-egm-check"
  {
    passthru.checkedHosts = builtins.attrNames homes;
    nativeBuildInputs = [ pkgs.nodejs ];
    EGM_PACKAGE = toString bundle;
    PI_PACKAGE_DIR = "${pi}/lib/node_modules/@earendil-works/pi-coding-agent";
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME" tests homes/profiles/pi-coding-agent
    cp ${./pi-egm.test.mjs} tests/pi-egm.test.mjs
    cp -r ${../homes/profiles/pi-coding-agent/egm} homes/profiles/pi-coding-agent/egm
    node --test tests/pi-egm.test.mjs
    touch "$out"
  ''
