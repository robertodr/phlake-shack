{ pkgs, ... }:

{
  programs.texlive = {
    enable = true;
    packageSet = with pkgs;
      (
        texlive.combine {
          inherit (texlive)
            collection-basic
            collection-bibtexextra
            collection-binextra
            collection-context
            collection-fontsextra
            collection-fontsrecommended
            collection-fontutils
            collection-formatsextra
            collection-langenglish
            collection-langeuropean
            collection-langfrench
            collection-langitalian
            collection-langother
            collection-latex
            collection-latexextra
            collection-latexrecommended
            collection-luatex
            collection-mathscience
            collection-metapost
            collection-pictures
            collection-plaingeneric
            collection-pstricks
            collection-publishers
            collection-xetex
            ;
        }
      )
    ;
  };
}
