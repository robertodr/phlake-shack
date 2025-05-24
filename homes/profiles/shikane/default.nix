{
  services.shikane = {
    enable = true;
    settings = {
      profile = [
        (import ./undocked.nix)
        (import ./docked.nix)
        (import ./uio.nix)
      ];
    };
  };
}
