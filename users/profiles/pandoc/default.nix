{
  programs.pandoc = {
    enable = true;
    default = {
      metadata = {
        # FIXME get it from the configuration
        author = "Roberto Di Remigio Eikås";
      };
      pdf-engine = "xelatex";
      citeproc = true;
    };
  };
}
