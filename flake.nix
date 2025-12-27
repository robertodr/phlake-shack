{
  description = "My NixOS systems and Home Manager configurations";

  inputs = {
    disko = {
      url = "github:nix-community/disko/?ref=v1.11.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence?rev=4b3e914cdf97a5b536a889e939fb2fd2b043a170";

    nix4vscode = {
      url = "github:nix-community/nix4vscode";
      inputs.nixpkgs.follows = "unstable";
    };

    nixos-hardware.url = "github:nixos/nixos-hardware";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    #nixpkgsWorkingZoom.url = "github:nixos/nixpkgs?rev=c74638883aabd10cdd020ca8dad0435aaf967a8f"; # 6.5.3.2773

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      disko,
      firefox-addons,
      home-manager,
      impermanence,
      nix4vscode,
      nixos-hardware,
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
                nixpkgs.overlays = [ nix4vscode.overlays.default ];
              }
            )
            ./systems/${system}/kellanved
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${user} = import (./. + "/homes/${user}@kellanved");
              home-manager.extraSpecialArgs = {
                inherit pkgsUnstable;
                firefox-addons-allowUnfree = pkgsUnstable.callPackage firefox-addons { };
              };
              home-manager.sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
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
