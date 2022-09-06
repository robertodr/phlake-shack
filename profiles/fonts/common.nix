{ pkgs
, ...
}:

{
  # TODO most of these fonts should be installed in a user profile
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
        nur.repos.robertodr.mplus-fonts
        open-sans
        terminus_font
        tex-gyre-math.bonum
        tex-gyre-math.pagella
        tex-gyre-math.schola
        tex-gyre-math.termes
        ubuntu_font_family
        unifont
        xits-math
      ];
  };
}
