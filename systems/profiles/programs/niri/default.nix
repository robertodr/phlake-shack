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
    systemPackages = [ pkgs.xwayland-satellite ];
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    xdgOpenUsePortal = true;
    config = {
      niri = {
        default = [
          "gnome"
          "gtk"
        ];
        # none
        #"org.freedesktop.impl.portal.Inhibit" = "none";
        # gnome
        "org.freedesktop.impl.portal.RemoteDesktop" = "gnome";
        "org.freedesktop.impl.portal.ScreenCast" = "gnome";
        "org.freedesktop.impl.portal.Screenshot" = "gnome";
        # GTK interfaces
        "org.freedesktop.impl.portal.Access" = "gtk";
        "org.freedesktop.impl.portal.AppChooser" = "gtk";
        "org.freedesktop.impl.portal.FileChooser" = "gtk";
        "org.freedesktop.impl.portal.Notification" = "gtk";
        "org.freedesktop.impl.portal.Print" = "gtk";
        #"org.freedesktop.impl.portal.Account" = "gtk";
        #"org.freedesktop.impl.portal.DynamicLauncher" = "gtk";
        #"org.freedesktop.impl.portal.Email" = "gtk";
        #"org.freedesktop.impl.portal.Lockdown" = "gtk";
        #"org.freedesktop.impl.portal.Notification" = "gtk";
        #"org.freedesktop.impl.portal.Settings" = "gtk";
        #"org.freedesktop.impl.portal.Wallpaper" = "gtk";
        # gnome-keyring
        "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
      };
    };
  };

  # hyprlock needs PAM access to authenticate, else it fallbacks to su
  # hyprlock and hypridle are installed/configured through home-manager
  security.pam.services.hyprlock = { };
  security.pam.services.niri.enableGnomeKeyring = true;
}
