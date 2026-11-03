{
  config,
  lib,
  pkgs,
  ...
}:
let
  fish = lib.getExe config.programs.fish.package;
in
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

  # Standalone Home Manager on a non-NixOS Nix installation: enable flakes in
  # ~/.config/nix/nix.conf. nix.package is only used to validate the file.
  nix = {
    package = pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # The macOS login shell stays /bin/zsh; bootstrap fish from interactive zsh,
  # like the NixOS hosts do from bash. Managed ~/.zshenv loads the Home Manager
  # session variables. Startup files stay in $HOME so the existing, unmanaged
  # ~/.zprofile (Homebrew) is still read before ~/.zshrc.
  programs.zsh = {
    enable = true;
    dotDir = config.home.homeDirectory;
    initContent = lib.mkBefore ''
      if [[ $(/bin/ps -o comm= -p $PPID) != *fish && -z $ZSH_EXECUTION_STRING ]]; then
        [[ -o login ]] && exec ${fish} --login
        exec ${fish}
      fi
    '';
  };
}
