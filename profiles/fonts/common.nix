{ pkgs
, ...
}:

{
  environment.systemPackages = with pkgs; [
    font-manager
  ];

  fonts = {
    fontDir.enable = true;
    fonts = with pkgs;
      [
        emacs-all-the-icons-fonts

        fira
        fira-code
        fira-code-symbols
        fira-mono

        corefonts
        inconsolata
        liberation_ttf
        dejavu_fonts
        bakoma_ttf
        gentium
        ubuntu_font_family
        terminus_font
      ];
  };
}
