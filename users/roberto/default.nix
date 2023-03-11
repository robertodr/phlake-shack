{
  hmUsers,
  pkgs,
  ...
}: {
  home-manager.users = {
    inherit (hmUsers) roberto;
  };

  imports = [./theme.nix];

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
      "input"
      "networkmanager"
      # I don't understand why I need to do this _explicitly_
      "onepassword"
      "onepassword-cli"
      "root"
      "systemd-journal"
      "users"
      "vboxusers"
      "video"
      "wheel"
    ];
    shell = pkgs.fish;
  };
}
