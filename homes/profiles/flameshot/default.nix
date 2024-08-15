{pkgs, ...}: {
  services.flameshot = {
    enable = true;
    package = pkgs.unstable.flameshot;
  };
}
