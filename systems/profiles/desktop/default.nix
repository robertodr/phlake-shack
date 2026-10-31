{ pkgs, ... }:
{
  imports = [
    ../fonts
    ../hardware/bluetooth
    ../programs/_1password
    ../programs/thunar
    ../programs/dconf
    ../services/dbus
    ../services/geoclue2
    ../services/hardware/bolt
    ../services/greetd
    ../services/upower
    ../programs/niri
    ../services/pipewire
    ../services/udisks2
    ../stylix
    ../zsa
  ];

  environment.systemPackages = [
    pkgs.xdg-utils
  ];
}
