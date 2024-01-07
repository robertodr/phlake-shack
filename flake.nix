{
  description = "My NixOS systems and Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";

    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:nixos/nixos-hardware";

    disko.url = "github:nix-community/disko?rev=aef9a509db64a081186af2dc185654d78dc8e344";

    impermanence.url = "github:nix-community/impermanence?rev=033643a45a4a920660ef91caa391fbffb14da466";

    #home-manager = {
    #  url = "github:nix-community/home-manager/release-23.11";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};

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

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.snowfall-lib.mkFlake {
      inherit inputs;

      channels-config = {
        allowUnfree = true;
      };

      # overlays = with inputs; [];

      systems.modules.nixos = with inputs; [
        disko.nixosModules.disko
        impermanence.nixosModules.impermanence
      ];

      systems.hosts.kellanved.modules = with inputs; [
        nixos-hardware.nixosModules.framework-12th-gen-intel
      ];

      src = ./.;
    };
}
