{ config, pkgs, ... }:
{
  programs.nh = {
    enable = true;
    # Default flake (NH_FLAKE) for `nh os` on NixOS hosts and `nh home` on
    # standalone Home Manager hosts. A string, not a path, so it points at the
    # mutable checkout instead of a store copy.
    flake = "${config.home.homeDirectory}/phlake-shack";
    clean = {
      enable = pkgs.stdenv.hostPlatform.isLinux;
      dates = "weekly";
      extraArgs = "--keep-since 7d --no-direnv";
    };
  };
}
