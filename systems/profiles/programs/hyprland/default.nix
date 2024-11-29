{pkgs, ...}: {
  programs.hyprland = {
    enable = true;
  };

  environment = {
    sessionVariables = {
      # needed for electron-based applications to look OK on Wayland
      NIXOS_OZONE_WL = "1";
    };
    pathsToLink = ["/share/xdg-desktop-portal" "/share/applications"];
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      # needed to make gtk apps happy
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  # hyprlock needs PAM access to authenticate, else it fallbacks to su
  # hyprlock and hypridle are installed/configured through home-manager
  security.pam.services.hyprlock = {};
}
