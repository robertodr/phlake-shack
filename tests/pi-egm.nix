{ self, pkgs }:
let
  inherit (pkgs) lib;
  linuxHomes = lib.genAttrs [ "kellanved" "dancer" ] (
    host: self.nixosConfigurations.${host}.config.home-manager.users.roberto
  );
  homes = linuxHomes // {
    crokus = self.homeConfigurations."robertoeikas@crokus".config;
  };
  validHome =
    home:
    let
      cfg = home.programs.pi-coding-agent;
      link = home.home.file."${cfg.configDir}/egm";
    in
    lib.elem (toString link.source) cfg.settings.packages
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
)) "EGM must remain a Pi-only intact package on Linux and Crokus";
pkgs.runCommand "pi-egm-check"
  {
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
