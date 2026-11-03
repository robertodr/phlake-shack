{ ... }:
{
  imports = [
    ../profiles/base
    ../profiles/development
    ../profiles/git/onepassword.nix
    ../profiles/ssh/onepassword.nix
  ];
  home = {
    username = "robertoeikas";
    homeDirectory = "/Users/robertoeikas";
    stateVersion = "26.05";
  };
}
