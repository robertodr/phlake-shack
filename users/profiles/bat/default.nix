{ pkgs, ... }:

{
  programs.bat = {
    enable = true;
    config = {
      theme = "Monokai Extended Origin";
      map-syntax = [
        ".*ignore:Git Ignore"
        ".gitconfig.local:Git Config"
      ];
    };
  };

  home.packages = with pkgs; [
    # Bash scripts that integrate bat with various command line tools.
    # https://github.com/eth-p/bat-extras/
    bat-extras.batman #     <- Read system manual pages (man) using bat as the manual page formatter.
    bat-extras.batgrep #    <- Quickly search through and highlight files using ripgrep.
    bat-extras.batdiff #    <- Diff a file against the current git index, or display the diff between two files.
    bat-extras.prettybat #  <- Pretty-print source code and highlight it with bat.
  ];
}
