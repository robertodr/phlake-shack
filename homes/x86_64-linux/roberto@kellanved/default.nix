{
  lib,
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [
    firefox
    gh
    zoom-us
  ];

  sessionVariables = {
    EDITOR = "nvim";
  };

  shellAliases = {
    vimdiff = "nvim -d";
  };
}
