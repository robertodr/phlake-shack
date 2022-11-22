{pkgs, ...}: {
  fonts = {
    fontDir.enable = true;

    fonts = with pkgs; [
      bakoma_ttf
      comfortaa
      corefonts
      dejavu_fonts
      fira
      fira-code
      fira-code-symbols
      fira-mono
      font-awesome
      gentium
      gyre-fonts
      inconsolata
      liberation_ttf
      lmmath
      material-design-icons
      material-icons
      (nerdfonts.override {fonts = ["FiraCode"];})
      nur.repos.robertodr.mplus-fonts
      open-sans
      openmoji-black
      openmoji-color
      terminus_font
      ubuntu_font_family
      unifont
      weather-icons
      xits-math
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
