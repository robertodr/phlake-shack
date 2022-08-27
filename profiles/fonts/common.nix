{ pkgs
, ...
}:

{
  fonts = {
    fontDir.enable = true;
    fonts = with pkgs;
      [
        bakoma_ttf
        comfortaa
        corefonts
        dejavu_fonts
        emacs-all-the-icons-fonts
        fira
        fira-code
        fira-code-symbols
        fira-mono
        gentium
        gyre-fonts
        inconsolata
        latinmodern-math
        liberation_ttf
        material-design-icons
        material-icons
        nerdfonts
        open-sans
        terminus_font
        tex-gyre-math.bonum
        tex-gyre-math.pagella
        tex-gyre-math.schola
        tex-gyre-math.termes
        ubuntu_font_family
        ubuntu_font_family
        unifont
        xits-math
      ];
  };
}
