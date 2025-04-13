{ pkgs, ... }:
{
  programs.pandoc = {
    enable = true;
    defaults = {
      metadata = {
        author = "Roberto Di Remigio Eikås";
      };
      pdf-engine = "xelatex";
      citeproc = true;
    };
  };

  home.packages = [
    pkgs.haskellPackages.pandoc-crossref
  ];
}
