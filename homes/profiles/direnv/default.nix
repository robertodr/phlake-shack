{ pkgsUnstable, ... }: {
  programs.direnv = {
    enable = true;
    nix-direnv = {
      enable = true;
      package = pkgsUnstable.nix-direnv;
    };
  };
}
