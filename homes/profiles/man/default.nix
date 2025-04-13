{ lib, ... }:
{
  programs.man = {
    enable = true;

    # N.B. This can slow down builds, but enables more manpage integrations
    # across various tools. See the home-manager manual for more info.
    generateCaches = lib.mkDefault true;
  };
}
