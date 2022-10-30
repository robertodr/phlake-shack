{
  hmUsers,
  pkgs,
  ...
}: {
  home-manager.users = {inherit (hmUsers) roberto;};

  users.users.roberto = {
    description = "Roberto Di Remigio Eikås";
    isNormalUser = true;
    home = "/home/roberto";
    createHome = true;
    hashedPassword = "$6$YoVa.tQqReqjgAav$KJ3u/TyGtsAiIpAqXbFqtRKjltfKsx5A5GSJLzP0zxMH1h6SeW.9aYEHB0gzjbgNkK.sIJDxaXdy/BYdLAVZu/";
    extraGroups = [
      "adm"
      "audio"
      "disk"
      "docker"
      "docker"
      "input"
      "networkmanager"
      "root"
      "systemd-journal"
      "users"
      "vboxusers"
      "video"
      "wheel"
      "wheel"
    ];
    shell = pkgs.fish;
  };
}
