{
  lib,
  pkgs,
  config,
  ...
}: {
  home = {
    username = "roberto";
    homeDirectory = "/home/roberto";
    packages = with pkgs; [
      firefox
      gh
      zoom-us
    ];

    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    #
    # You can update Home Manager without changing this value. See
    # the Home Manager release notes for a list of state version
    # changes in each release.
    stateVersion = "23.11";

    sessionVariables = {
      EDITOR = "nvim";
    };

    shellAliases = {
      vimdiff = "nvim -d";
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  imports = map (x: ./.. + ("/profiles/" + x)) [
    "gh"
    "git"
    "ssh"
  ];
}
