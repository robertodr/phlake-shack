{
  config,
  pkgs,
  ...
}:
let
  rev = "2c12a0b15f33fa9b6e2a29f91f7b1da3e7a80c3b";
  sha256 = "sha256-p0nK1I0H4Zb/ExHnEC1wgpJJhC0RpgxWUsuwQetNM+Q=";
  mkExt =
    name:
    config.lib.vicinae.mkExtension {
      inherit name;
      src =
        pkgs.fetchFromGitHub {
          owner = "vicinaehq";
          repo = "extensions";
          inherit rev sha256;
        }
        + "/extensions/${name}";
    };
in
{
  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    extensions = map mkExt [
      "nix"
      "bluetooth"
      "player-pilot"
      #"systemd"
      "pulseaudio"
    ];
  };
}
