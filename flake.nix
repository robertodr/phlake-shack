{
  description = "My NixOS systems and Home Manager configurations";

  inputs = {
    bun2nix = {
      url = "github:nix-community/bun2nix?ref=2.1.2";
    };

    disko = {
      url = "github:nix-community/disko?tag=v1.13.0";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
    };

    impermanence = {
      url = "github:nix-community/impermanence?rev=7b1d382faf603b6d264f58627330f9faa5cba149";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "unstable";
    };

    nix4vscode = {
      url = "github:nix-community/nix4vscode";
      inputs.nixpkgs.follows = "unstable";
    };

    nixos-hardware = {
      url = "github:nixos/nixos-hardware";
    };

    noctalia = {
      # Track the latest revision already built by Noctalia's binary cache.
      url = "github:noctalia-dev/noctalia/cachix";
    };

    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-26.05";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
    };

    stylix = {
      url = "github:nix-community/stylix/release-26.05";
    };

    unstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
  };

  outputs =
    {
      bun2nix,
      disko,
      home-manager,
      impermanence,
      llm-agents,
      nix4vscode,
      nixos-hardware,
      noctalia,
      nixpkgs,
      sops-nix,
      stylix,
      unstable,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      user = "roberto";
      pkgsUnstable = import unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations = {
        kellanved = nixpkgs.lib.nixosSystem {
          modules = [
            (
              { config, ... }:
              {
                # This enables unfree for the 'pkgs' (stable) set
                nixpkgs.config.allowUnfree = true;
                nixpkgs.overlays = [
                  llm-agents.overlays.shared-nixpkgs
                  nix4vscode.overlays.default
                  (final: prev: {
                    kenn-forge = final.callPackage ./pkgs/kenn-forge {
                      bun2nix = inputs.bun2nix.packages.${system}.default;
                    };
                  })
                ];
              }
            )
            ./systems/${system}/kellanved
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                backupFileExtension = "bak";
                extraSpecialArgs = {
                  inherit pkgsUnstable;
                };
                sharedModules = [
                  ./homes/modules
                  noctalia.homeModules.default
                ];
                useGlobalPkgs = true;
                useUserPackages = true;
                users.${user} = import (./. + "/homes/${user}-at-kellanved");
              };
            }
            impermanence.nixosModules.impermanence
            nixos-hardware.nixosModules.framework-13-7040-amd
            sops-nix.nixosModules.sops
            stylix.nixosModules.stylix
          ];
          specialArgs = {
            inherit pkgsUnstable;
          };
        };
      };
    };
}
