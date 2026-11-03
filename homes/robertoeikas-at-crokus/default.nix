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
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Prebuilt llm-agents packages (pkgs.llm-agents). The multi-user daemon
      # only honours this if /etc/nix/nix.conf lists the cache in
      # trusted-substituters and its key in trusted-public-keys.
      extra-substituters = [ "https://cache.numtide.com" ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };
  };

  # fish's macOS login setup (__fish_macos_set_env) rebuilds PATH from
  # /etc/paths, pushing the Nix profiles behind /usr/bin; move them back in
  # front so Nix-installed tools win over the system ones, as in zsh.
  programs.fish.loginShellInit = ''
    fish_add_path --global --move --path $HOME/.nix-profile/bin /nix/var/nix/profiles/default/bin
  '';

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
