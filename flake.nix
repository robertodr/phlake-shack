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
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence?rev=4b3e914cdf97a5b536a889e939fb2fd2b043a170";

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.6.0";

    nixos-hardware.url = "github:nixos/nixos-hardware";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix/release-24.11";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
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
      nix-flatpak,
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
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      pkgsUnstable = import unstable {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
    in
    {
      nixosConfigurations = {
        kellanved = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit pkgs pkgsUnstable; };
          modules = [
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
            nix-flatpak.nixosModules.nix-flatpak
            nixos-hardware.nixosModules.framework-13-7040-amd
            sops-nix.nixosModules.sops
            stylix.nixosModules.stylix
          ];
        };
      };
    };
}
