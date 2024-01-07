{
  description = "My NixOS systems and Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";

    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:nixos/nixos-hardware";

    disko.url = "github:nix-community/disko?rev=aef9a509db64a081186af2dc185654d78dc8e344";

    impermanence.url = "github:nix-community/impermanence?rev=033643a45a4a920660ef91caa391fbffb14da466";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #nur = {
    #  url = "github:nix-community/NUR";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};

    #base16-schemes = {
    #  url = "github:tinted-theming/schemes?dir=base16";
    #  flake = false;
    #};

    #stylix = {
    #  url = "github:danth/stylix";
    #  inputs = {
    #    nixpkgs.follows = "nixpkgs";
    #    home-manager.follows = "home";
    #  };
    #};
  };

  outputs = {
    self,
    nixpkgs,
    unstable,
    nixos-hardware,
    disko,
    impermanence,
    home-manager,
  }: {
    nixosConfigurations = {
      kellanved = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./systems/x86_64-linux/kellanved
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.roberto = import (./. + "/homes/x86_64-linux/roberto@kellanved");
          }
          nixos-hardware.nixosModules.framework-12th-gen-intel
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
        ];
      };
    };
  };
}
