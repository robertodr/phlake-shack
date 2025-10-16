{ pkgs, ... }:

{
  programs.niri = {
    enable = true;
  };

  environment = {
    sessionVariables = {
      # needed for electron-based applications to look OK on Wayland
      NIXOS_OZONE_WL = "1";
    };
    systemPackages = [pkgs.xwayland-satellite];
  };
}
