{pkgs, ...}: {
  users = {
    groups = {
      roberto = {gid = 1000;};
    };
    users = {
      # NOTE in case you need to change the UID
      # 1. Log in as root
      # 2. Edit this file to change the uid field
      # 3. Edit /etc/passwd to change the uid of the user
      # 4. Run chown -Rhc --from=$old_uid $new_uid /
      # 5. Rebuild configuration
      roberto = {
        isNormalUser = true;
        description = "Roberto Di Remigio Eikås";
        group = "roberto";
        home = "/home/roberto";
        createHome = true;
        uid = 1000;
        extraGroups = [
          "docker"
          "input"
          "networkmanager"
          "users"
          "wheel"
        ];
        #extraGroups = [
        #  "adm"
        #  "audio"
        #  "disk"
        #  "docker"
        #  "input"
        #  "networkmanager"
        #  # I don't understand why I need to do this _explicitly_
        #  "onepassword"
        #  "onepassword-cli"
        #  "root"
        #  "systemd-journal"
        #  "users"
        #  "vboxusers"
        #  "video"
        #  "wheel"
        #];
        shell = pkgs.fish;
        hashedPassword = "$y$j9T$9CT7imGp.njKexGkzwsTh/$7y/T3A6cPIvy7CFKEBOJzil4sJmof0IaFR9BlJr2b15";
      };
    };
  };

  programs.fish.enable = true;
}
