{ lib, pkgs, ... }:
{
  programs.man = {
    enable = true;

    # N.B. This can slow down builds, but enables more manpage integrations
    # across various tools. See the home-manager manual for more info.
    # Darwin uses the system man with HM stateVersion >= 26.05.
    generateCaches = if pkgs.stdenv.hostPlatform.isDarwin then false else lib.mkDefault true;
  };
}
