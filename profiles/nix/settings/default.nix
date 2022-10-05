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

      extra-substituters = [
        "https://cache.floxdev.com?trusted=1"
      ];
      extra-truster-public-keys = [
        "flox-store-public-0:8c/B+kjIaQ+BloCmNkRUKwaVPFWkriSAd0JJvuDu4F0="
      ];
    };
  };
}
