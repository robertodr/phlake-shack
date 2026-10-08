{ lib, ... }:
{
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PubkeyAuthentication = true;
    };
  };

  users.users.roberto.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICJ9IOPT5M3d01EAiSbDV7fCpqO2mEqH2ibbZoTSfZ+H kellanved"
  ];

  networking.nftables.enable = lib.mkForce false;
  networking.firewall = {
    enable = true;
    extraCommands = ''
      iptables -w -I nixos-fw 1 -p tcp --dport 22 -j REJECT --reject-with tcp-reset
      iptables -w -I nixos-fw 1 -p tcp --dport 22 -s 192.168.68.0/22 -j nixos-fw-accept
      ip6tables -w -I nixos-fw 1 -p tcp --dport 22 -j REJECT --reject-with tcp-reset
    '';
  };
}
