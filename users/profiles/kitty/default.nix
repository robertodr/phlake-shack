{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    font = {
      package = pkgs.fira-code;
      # TODO the retina variant is actually in nerdfonts!
      name = "Fira Code Retina";
      size = 14;
    };
    theme = "Japanesque";
  };
}
