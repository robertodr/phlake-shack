{ pkgs, ... }:
{
  programs.nh = {
    enable = true;
    clean = {
      enable = pkgs.stdenv.hostPlatform.isLinux;
      dates = "weekly";
      extraArgs = "--keep-since 7d --no-direnv";
    };
  };
}
