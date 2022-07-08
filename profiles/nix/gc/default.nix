# collect Nix garbage-collection options

{ pkgs, lib, ... }:

{
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # trigger a garbage collection when the minimum free space drops below 1 GiB
  nix.settings.min-free = 1024 * 1024 * 1024;
}
