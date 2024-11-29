{
  description = "My NixOS systems and Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";

    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:nixos/nixos-hardware";

    disko = {
      url = "github:nix-community/disko?rev=aef9a509db64a081186af2dc185654d78dc8e344";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence?rev=033643a45a4a920660ef91caa391fbffb14da466";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix/release-24.05";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    disko,
    home-manager,
    impermanence,
    nixos-hardware,
    sops-nix,
    stylix,
    unstable,
    firefox-addons,
  } @ inputs: let
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
  in {
    nixosConfigurations = {
      kellanved = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit pkgs pkgsUnstable;};
        modules = [
          ./systems/x86_64-linux/kellanved
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${user} = import (./. + "/homes/${user}@kellanved");
            home-manager.extraSpecialArgs = {
              inherit pkgsUnstable;
              firefox-addons-allowUnfree = pkgsUnstable.callPackage firefox-addons {};
            };
            home-manager.sharedModules = [inputs.sops-nix.homeManagerModules.sops];
          }
          impermanence.nixosModules.impermanence
          nixos-hardware.nixosModules.framework-12th-gen-intel
          sops-nix.nixosModules.sops
          stylix.nixosModules.stylix
        ];
      };
    };
  };
}
