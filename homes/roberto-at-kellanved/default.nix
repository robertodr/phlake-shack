{ pkgs, ... }:
{
  home.stateVersion = "24.11";
  home.packages = [ pkgs.oleafly ];

  imports = [
    ../profiles/base
    ../profiles/development
    ../profiles/desktop
    ../profiles/git/desktop.nix
    ../profiles/git/onepassword.nix
    ../profiles/ssh/onepassword.nix
    ../profiles/kenn-forge
  ];
}
