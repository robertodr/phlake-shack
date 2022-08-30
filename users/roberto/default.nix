{ hmUsers, pkgs, ... }:
{
  home-manager.users = { inherit (hmUsers) roberto; };

  users.users.roberto = {
    description = "Roberto Di Remigio";
    isNormalUser = true;
    home = "/home/roberto";
    createHome = true;
    hashedPassword = "$6$YoVa.tQqReqjgAav$KJ3u/TyGtsAiIpAqXbFqtRKjltfKsx5A5GSJLzP0zxMH1h6SeW.9aYEHB0gzjbgNkK.sIJDxaXdy/BYdLAVZu/";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };
}
