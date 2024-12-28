# FIXME this is a simplification of the module in https://github.com/nix-community/home-manager/pull/4096
{
  lib,
  pkgs,
  ...
}: let
  shikanePkg = pkgs.shikane;
  tomlFormat = pkgs.formats.toml {};

  settings = {
    profile = [
      ./undocked.nix
      ./docked.nix
      ./uio.nix
    ];
  };
in {
  home.packages = [
    pkgs.wdisplays
    shikanePkg
  ];

  systemd.user.services.shikane = {
    Unit = {
      Description = "Dynamic output configuration tool";
      Documentation = "man:shikane(1)";
      After = ["graphical-session-pre.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      ExecStart =
        lib.escapeShellArgs [(lib.getExe shikanePkg) "--config" (tomlFormat.generate "shikane-config" settings)];
    };

    Install = {WantedBy = ["graphical-session.target"];};
  };
}
