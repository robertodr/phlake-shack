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
      extension = home.home.file."${cfg.configDir}/extensions/bounded-compaction";
    in
    cfg.settings.compaction.keepRecentTokens == 8000
    && cfg.settings.compaction.reserveTokens == 32768
    && extension.source == ../homes/profiles/pi-coding-agent/bounded-compaction
    && !extension.recursive;
  pi = linuxHomes.kellanved.programs.pi-coding-agent.package;
in
assert lib.assertMsg (lib.all validHome (
  builtins.attrValues homes
)) "Every Pi home must install bounded compaction and reduced retention";
pkgs.runCommand "pi-bounded-compaction"
  {
    nativeBuildInputs = [ pkgs.nodejs ];
    PI_PACKAGE_DIR = "${pi}/lib/node_modules/@earendil-works/pi-coding-agent";
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    # Copy just this test and extension, retaining their relative import layout.
    mkdir -p tests homes/profiles/pi-coding-agent
    cp ${./pi-bounded-compaction.test.mjs} tests/pi-bounded-compaction.test.mjs
    cp -r ${../homes/profiles/pi-coding-agent/bounded-compaction} \
      homes/profiles/pi-coding-agent/bounded-compaction
    node --test tests/pi-bounded-compaction.test.mjs
    touch "$out"
  ''
