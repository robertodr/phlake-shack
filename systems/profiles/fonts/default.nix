{
  lib,
  pkgs,
  ...
}:
{
  fonts = {
    fontDir.enable = true;

    packages =
      lib.attrVals [
        "bakoma_ttf"
        "comfortaa"
        "corefonts"
        "dejavu_fonts"
        "fira"
        "fira-code"
        "fira-code-symbols"
        "fira-mono"
        "font-awesome"
        "gentium"
        "gyre-fonts"
        "inconsolata"
        "julia-mono"
        "liberation_ttf"
        "lmmath"
        "material-design-icons"
        "material-icons"
        "noto-fonts-color-emoji"
        "open-sans"
        "terminus_font"
        "ubuntu-classic"
        "unifont"
        "weather-icons"
        "xits-math"
      ] pkgs
      ++ [
        (pkgs.mplus-outline-fonts.githubRelease)
        (pkgs.nerd-fonts.fira-code)
      ];

    fontconfig = {
      enable = true;
      antialias = true;
    };
  };
}
