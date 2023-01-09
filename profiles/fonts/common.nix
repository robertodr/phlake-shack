{
  lib,
  pkgs,
  ...
}: {
  fonts = {
    fontDir.enable = true;

    fonts =
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
        "open-sans"
        "openmoji-black"
        "openmoji-color"
        "terminus_font"
        "ubuntu_font_family"
        "unifont"
        "weather-icons"
        "xits-math"
      ]
      pkgs
      ++ [
        (pkgs.nerdfonts.override {fonts = ["FiraCode"];})
        pkgs.nur.repos.robertodr.mplus-fonts
      ];

    fontconfig = {
      enable = true;
      antialias = true;
      defaultFonts = {
        serif = ["Gentium"];
        sansSerif = ["M PLUS 2"];
        monospace = ["Fira Code"];
        emoji = ["OpenMoji Color"];
      };
    };
  };
}
