# FIXME this is a simplification of the module in https://github.com/nix-community/home-manager/pull/4096
{
  lib,
  pkgs,
  ...
}:
let
  shikanePkg = pkgs.shikane;
  tomlFormat = pkgs.formats.toml { };

  settings = {
    profile = [
      (import ./undocked.nix)
      (import ./docked.nix)
      (import ./uio.nix)
    ];
  };
in
{
  home.packages = [
    pkgs.wdisplays
    shikanePkg
  ];

  xdg.configFile."shikane/config.toml".source = tomlFormat.generate "shikane-config" settings;

  systemd.user.services.shikane = {
    Unit = {
      Description = "Dynamic output configuration tool";
      Documentation = "man:shikane(1)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = lib.getExe shikanePkg;
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
