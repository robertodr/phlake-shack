{pkgs, ...}:

{
  programs.pandoc = {
    enable = true;
    defaults = {
      metadata = {
        # FIXME get it from the configuration
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
