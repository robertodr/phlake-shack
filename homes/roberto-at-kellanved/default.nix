{ ... }:
{
  home.stateVersion = "24.11";

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
