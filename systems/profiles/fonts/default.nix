{
  lib,
  pkgs,
  ...
}: {
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
        "liberation_ttf"
        "lmmath"
        "material-design-icons"
        "material-icons"
        "noto-fonts-emoji"
        "open-sans"
        "terminus_font"
        "ubuntu_font_family"
        "unifont"
        "weather-icons"
        "xits-math"
      ]
      pkgs
      ++ [
        (pkgs.mplus-outline-fonts.githubRelease)
        (pkgs.nerdfonts.override {fonts = ["FiraCode"];})
      ];

    fontconfig = {
      enable = true;
      antialias = true;
    };
  };
}
