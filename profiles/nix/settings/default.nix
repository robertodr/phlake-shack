# collect Nix settings

{ ... }:

{
  nix = {
    optimise.automatic = true;

    settings = {
      system-features = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      # automate `nix-store --optimise`
      auto-optimise-store = true;

      cores = 2;

      # prevents impurities in builds
      sandbox = true;

      allowed-users = [ "@users" ];
      trusted-users = [ "root" "@wheel" ];
      keep-outputs = true;
      keep-derivations = true;
      fallback = true;
      substituters = [ "https://cache.nixos.org/" ];
    };
  };
}
