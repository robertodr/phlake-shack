{pkgs, ...}: {
  # TODO most of these fonts should be installed in a user profile
  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      # FIXME why does this give a hash mismatch?
      #nur.repos.robertodr.mplus-fonts
      bakoma_ttf
      comfortaa
      corefonts
      dejavu_fonts
      fira
      fira-code
      fira-code-symbols
      fira-mono
      gentium
      gyre-fonts
      inconsolata
      liberation_ttf
      lmmath
      material-design-icons
      material-icons
      mplus-outline-fonts.githubRelease
      nerdfonts
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
