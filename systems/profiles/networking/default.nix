{ lib, pkgs, ... }:
{
  # fixes to get eduroam working: https://bbs.archlinux.org/viewtopic.php?pid=1751610#p1751610
  networking = {
    hostName = "kellanved";
    dhcpcd.enable = false;
    networkmanager = {
      enable = true;
      dhcp = "internal";
      plugins = with pkgs; [
        networkmanager-fortisslvpn
        networkmanager-iodine
        networkmanager-l2tp
        networkmanager-openconnect
        networkmanager-openvpn
        networkmanager-sstp
        networkmanager-strongswan
        networkmanager-vpnc
      ];
    };
    useDHCP = lib.mkDefault false;
  };

  environment.etc."strongswan.conf".text = "";
}
