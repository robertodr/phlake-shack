{
  config,
  pkgs,
  ...
}:
{
  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    extensions = [
      (config.lib.vicinae.mkExtension {
        name = "nix";
        src =
          pkgs.fetchFromGitHub {
            owner = "vicinaehq";
            repo = "extensions";
            rev = "e01fe274f037e4d2b7436718258fa898f80dc4b2";
            sha256 = "sha256-/Yx97SOwvJXPxvv6e81j+ID87J9DQGq0QGYnmsWKoz8=";
          }
          + "/extensions/nix";
      })

      (config.lib.vicinae.mkExtension {
        name = "bluetooth";
        src =
          pkgs.fetchFromGitHub {
            owner = "vicinaehq";
            repo = "extensions";
            rev = "e01fe274f037e4d2b7436718258fa898f80dc4b2";
            sha256 = "sha256-/Yx97SOwvJXPxvv6e81j+ID87J9DQGq0QGYnmsWKoz8=";
          }
          + "/extensions/bluetooth";
      })
    ];
  };
}
