{
  hmUsers,
  pkgs,
  ...
}: {
  home-manager.users = {
    inherit (hmUsers) roberto;
  };

  imports = [./theme.nix];

  # NOTE in case you need to change the UID
  # 1. Log in as root
  # 2. Edit this file to change the uid field
  # 3. Edit /etc/passwd to change the uid of the user
  # 4. Run chown -Rhc --from=$old_uid $new_uid /
  # 5. Rebuild configuration
  users.users.roberto = {
    description = "Roberto Di Remigio Eikås";
    isNormalUser = true;
    home = "/home/roberto";
    uid = 1000;
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

  programs.fish.enable = true;
}
