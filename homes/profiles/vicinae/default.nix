{
  config,
  pkgs,
  ...
}:
let
  rev = "d12bcb134d45dedad1a28a18e1cd8807353338d0";
  sha256 = "sha256-/Yx97SOwvJXPxvv6e81j+ID87J9DQGq0QGYnmsWKoz8=";
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
