{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      bbenoist.nix
      ms-pyright.pyright
      ms-python.python
      ms-toolsai.jupyter
      ms-vscode.cpptools
      ms-vsliveshare.vsliveshare
      vscodevim.vim
    ];
  };
}
