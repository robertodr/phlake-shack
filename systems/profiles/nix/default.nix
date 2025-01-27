{
  pkgs,
  lib,
  ...
}: let
  folder = ./cachix;
  toImport = name: value: folder + ("/" + name);
  filterCaches = key: value: value == "regular" && lib.hasSuffix ".nix" key && key != "default.nix";
  imports = lib.mapAttrsToList toImport (lib.filterAttrs filterCaches (builtins.readDir folder));
in {
  inherit imports;
  nix = {
    optimise.automatic = true;

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    settings = {
      cores = 4;
      experimental-features = ["nix-command" "flakes"];
      system-features = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      # automate `nix-store --optimise`
      auto-optimise-store = true;
      # prevents impurities in builds
      sandbox = true;
      allowed-users = ["@users"];
      trusted-users = ["root" "@wheel"];
      keep-outputs = true;
      keep-derivations = true;
      fallback = true;
      # trigger a garbage collection when the minimum free space drops below 1 GiB
      min-free = 1024 * 1024 * 1024;
      substituters = ["https://cache.nixos.org/" "https://cache.flox.dev"];
      trusted-substituters = ["https://cache.flox.dev"];
      trusted-public-keys = ["flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="];
    };
  };
}
