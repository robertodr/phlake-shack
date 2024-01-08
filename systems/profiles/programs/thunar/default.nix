{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  services = {
    # Mount, trash, and other functionalities
    gvfs.enable = true;
    # Thumbnail support for images
    tumbler.enable = true;
  };

  environment.systemPackages = with pkgs; [
    xarchiver
  ];
}
