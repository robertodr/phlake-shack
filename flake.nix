{
  description = "A highly structured configuration database.";

  nixConfig.extra-experimental-features = "nix-command flakes";
  nixConfig.extra-substituters = "https://nrdxp.cachix.org https://nix-community.cachix.org";
  nixConfig.extra-trusted-public-keys = "nrdxp.cachix.org-1:Fc5PSqY2Jm1TrWfm88l6cvGWwz3s93c6IOifQWnhNW4= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";

  inputs =
    {
      # Track channels with commits tested and built by hydra
      nixos.url = "github:nixos/nixpkgs/nixos-22.05";
      latest.url = "github:nixos/nixpkgs/nixos-unstable";

      home = {
        url = "github:nix-community/home-manager/release-22.05";
        inputs.nixpkgs.follows = "nixos";
      };

      nixos-hardware.url = "github:nixos/nixos-hardware";

      nixos-generators.url = "github:nix-community/nixos-generators";

      digga = {
        url = "github:divnix/digga";
        inputs = {
          nixpkgs.follows = "nixos";
          nixlib.follows = "nixos";
          home-manager.follows = "home";
          deploy.follows = "deploy";
        };
      };

      # bleeding edge emacs overlay
      emacs-overlay = {
        url = "github:nix-community/emacs-overlay";
        inputs.nixpkgs.follows = "nixos";
      };

      # a simple multi-profile Nix-flake deploy tool.
      deploy = {
        url = "github:serokell/deploy-rs";
        inputs.nixpkgs.follows = "nixos";
      };

      # age-encrypted secrets for NixOS
      agenix = {
        url = "github:ryantm/agenix";
        inputs.nixpkgs.follows = "nixos";
      };

      # generate nix sources expr for the latest version of packages
      nvfetcher = {
        url = "github:berberman/nvfetcher";
        inputs.nixpkgs.follows = "nixos";
      };

      # my NUR packages
      robertodr = {
        url = "github:robertodr/nur-packages";
        inputs.nixpkgs.follows = "nixos";
      };
    };

  outputs =
    { self
    , digga
    , nixos
    , home
    , nixos-hardware
    , nur
    , agenix
    , nvfetcher
    , deploy
    , nixpkgs
    , emacs-overlay
    , ...
    } @ inputs:
    digga.lib.mkFlake
      {
        inherit self inputs;

        supportedSystems = [
          "x86_64-linux"
          # "aarch64-linux"
        ];

        channelsConfig = { allowUnfree = true; };

        channels = {
          nixos = {
            imports = [ (digga.lib.importOverlays ./overlays) ];
            overlays = [
              inputs.emacs-overlay.overlay
            ];
          };
          latest = {
            overlays = [ ];
          };
        };

        lib = import ./lib { lib = digga.lib // nixos.lib; };

        sharedOverlays = [
          (final: prev: {
            __dontExport = true;
            lib = prev.lib.extend (lfinal: lprev: {
              our = self.lib;
            });
          })

          nur.overlay
          agenix.overlay
          emacs-overlay.overlay
          nvfetcher.overlay

          (import ./pkgs)
        ];

        nixos = {
          hostDefaults = {
            system = "x86_64-linux";
            channelName = "nixos";
            imports = [ (digga.lib.importExportableModules ./modules) ];
            modules = [
              { lib.our = self.lib; }
              digga.nixosModules.bootstrapIso
              digga.nixosModules.nixConfig
              home.nixosModules.home-manager
              agenix.nixosModules.age
            ];
          };

          imports = [ (digga.lib.importHosts ./hosts) ];
          hosts = {
            # set host-specific properties here
            zoidberg = {
              system = "x86_64-linux";
              channelName = "latest";
              modules = [ nixos-hardware.nixosModules.lenovo-thinkpad-x1 ];
            };
          };
          importables = rec {
            profiles = digga.lib.rakeLeaves ./profiles // {
              users = digga.lib.rakeLeaves ./users;
            };
            # suites provide a mechanism for users to easily combine and name collections of profiles
            suites = nixos.lib.fix (suites: {
              nix-settings = with profiles.nix; [ cachix gc settings ];

              base = suites.nix-settings ++
                (with profiles; [
                  core
                  fonts.common
                  services.earlyoom
                  services.fwupd
                  services.openssh
                  services.thermald
                  services.tlp
                  users.root
                  systemd
                  hardware.bluetooth
                  services.hardware.bolt
                  programs._1password
                ]);

              i3 = with profiles; [
                programs.dconf
                services.xserver
                services.blueman
                services.dbus
                services.upower
              ];

              # TODO add borgbackup service
              backup = with profiles; [
                services.borgbackup
              ];

              # thinkpad specifics
              thinkpad = with profiles; [
                services.thinkfan
              ];

              networking = with profiles; [
              ];

              multimedia = with profiles; [
                services.printing
              ];

              development = with profiles; [
              ];

              virtualisation = with profiles; [
                programs.singularity
                virtualisation.docker
                virtualisation.virtualbox
              ];
            });
          };
        };

        home = {
          imports = [ (digga.lib.importExportableModules ./users/modules) ];
          modules = [
            # TODO nix flake show broken due to IFD
            # see https://github.com/nix-community/home-manager/issues/1262
            { manual.manpages.enable = false; }
          ];
          importables = rec {
            profiles = digga.lib.rakeLeaves ./users/profiles;
            # suites provide a mechanism for users to easily combine and name collections of profiles
            suites = nixos.lib.fix (suites: {
              base = with profiles; [ core desktop-applications ];
              multimedia = with profiles; [ ];
              development = with profiles; [ direnv emacs ];
              synchronize = with profiles; [ ];
            });
          };
          users = {
            roberto = { suites, ... }: { imports = with suites; base ++ development; };
          }; # digga.lib.importers.rakeLeaves ./users/hm;
        };

        devshell = ./shell;

        homeConfigurations = digga.lib.mergeAny
          (digga.lib.mkHomeConfigurations self.nixosConfigurations)
        ;

        deploy.nodes = digga.lib.mkDeployNodes self.nixosConfigurations { };

      }
  ;
}
