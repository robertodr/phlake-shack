{
  config,
  lib,
  pkgs,
  ...
}:
let
  rev = "63e239d8d4c3ddc6774faf533b4997405f78c549";
  bundle = pkgs.fetchzip {
    name = "elephant-goldfish-model-${rev}";
    url = "https://codeload.github.com/google/elephant-goldfish-model/tar.gz/${rev}";
    extension = "tar.gz";
    hash = "sha256-MP2AFn7LiBlzxqALEjtOIBCojqkXWUvqeSIhu3sMtOY=";
  };
  codex =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex"
    else
      "${config.home.homeDirectory}/.codex";
  marketplace = "${codex}/marketplaces/egm";
  # Codex enumerates real version directories; a symlink named 0.1.1 is skipped.
  cache = pkgs.runCommand "egm-codex-cache" { nativeBuildInputs = [ pkgs.jq ]; } ''
    version=$(jq -er '.version | select(test("^[0-9]+[.][0-9]+[.][0-9]+$"))' ${bundle}/.codex-plugin/plugin.json)
    mkdir -p "$out/egm/$version"
    cp -rs ${bundle}/. "$out/egm/$version/"
  '';
in
{
  options.profiles.agent-clis.egm.enable =
    lib.mkEnableOption "the pinned EGM reviewer plugin in selected supported CLIs";
  config = lib.mkIf config.profiles.agent-clis.egm.enable {
    programs.claude-code.plugins = lib.mkIf config.programs.claude-code.enable [ bundle ];
    programs.codex.settings = lib.mkIf config.programs.codex.enable {
      marketplaces.egm = {
        source_type = "local";
        source = marketplace;
      };
      plugins."egm@egm".enabled = true;
    };
    home.file = lib.mkMerge [
      (lib.mkIf config.programs.antigravity-cli.enable { ".gemini/config/plugins/egm".source = bundle; })
      (lib.mkIf config.programs.codex.enable {
        "${marketplace}".source = bundle;
        "${codex}/plugins/cache/egm".source = cache;
      })
    ];
  };
}
