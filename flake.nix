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

    nur.url = "github:nix-community/NUR";

    stylix = {
      url = "github:danth/stylix/release-24.05";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #firefox-addons = {
    #  url = "git+https://gitlab.com/rycee/nur-expressions?dir=pkgs/firefox-addons";
    #  inputs.nixpkgs.follows = "nixpkgs";
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
    nur,
    stylix,
    nix-vscode-extensions,
    agenix,
  } @ inputs: let
    system = "x86_64-linux";
    user = "roberto";
  in {
    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    nixosConfigurations = {
      inherit system;
      kellanved = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./systems/x86_64-linux/kellanved
          agenix.nixosModules.default
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${user} = import (./. + "/homes/${user}@kellanved");
            home-manager.extraSpecialArgs = {inherit inputs nix-vscode-extensions;};
          }
          nixos-hardware.nixosModules.framework-12th-gen-intel
          stylix.nixosModules.stylix
          {nixpkgs.overlays = [nur.overlay];}
        ];
      };
    };
  };
}
