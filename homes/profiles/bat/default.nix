{ pkgs, ... }:
{
  programs.bat = {
    enable = true;
    config = {
      map-syntax = [
        ".*ignore:Git Ignore"
        ".gitconfig.local:Git Config"
      ];
    };
    # Bash scripts that integrate bat with various command line tools.
    # https://github.com/eth-p/bat-extras/
    extraPackages = with pkgs.bat-extras; [
      batman # <- Read system manual pages (man) using bat as the manual page formatter.
      batgrep # <- Quickly search through and highlight files using ripgrep.
      batdiff # <- Diff a file against the current git index, or display the diff between two files.
      prettybat # <- Pretty-print source code and highlight it with bat.
    ];
  };

  home.shellAliases = {
    cat = "bat";
  };
}
