{ hmUsers, pkgs, ... }:
{
  home-manager.users = { inherit (hmUsers) roberto; };

  users.users.roberto = {
    description = "Roberto Di Remigio";
    isNormalUser = true;
    home = "/home/roberto";
    createHome = true;
    hashedPassword = "$6$VPXpiL6LFfpJ03pb$6M6ecxz66NRsmJpLReD7.uAaJ.Osb1yiOfSm2avN8mQ7.bJXB5YMnxMNvQK6soethO3ojFo93E30rkBr.AqEH1";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    packages = with pkgs; [
      neovim
    ];
  };
}
