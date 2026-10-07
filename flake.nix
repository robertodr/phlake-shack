{
  description = "My NixOS systems and Home Manager configurations";

  inputs = {
    bun2nix = {
      url = "github:nix-community/bun2nix?ref=2.1.2";
    };

    disko = {
      url = "github:nix-community/disko?tag=v1.13.0";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
    };

    impermanence = {
      url = "github:nix-community/impermanence?rev=7b1d382faf603b6d264f58627330f9faa5cba149";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
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

    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
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
      disko,
      home-manager,
      impermanence,
      llm-agents,
      nix4vscode,
      nixos-hardware,
      noctalia,
      noctalia-greeter,
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

      preCommitCheck = inputs.git-hooks.lib.${system}.run {
        src = ./.;
        package = nixpkgs.legacyPackages.${system}.prek;
        hooks = {
          deadnix.enable = true;
          nixfmt.enable = true;
          statix.enable = true;
        };
      };

      mkHost =
        {
          name,
          hardwareModule,
          homeModule,
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          modules = [
            (_: {
              # This enables unfree for the 'pkgs' (stable) set
              nixpkgs.config.allowUnfree = true;
              nixpkgs.overlays = [
                llm-agents.overlays.shared-nixpkgs
                nix4vscode.overlays.default
                (final: _prev: {
                  kenn-forge = final.callPackage ./pkgs/kenn-forge {
                    bun2nix = inputs.bun2nix.packages.${system}.default;
                  };
                })
              ];
            })
            (./. + "/systems/${system}/${name}")
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                backupFileExtension = "bak";
                extraSpecialArgs = {
                  inherit pkgsUnstable;
                  gitbutlerPackage = llm-agents.packages.${system}.gitbutler;
                  gitbutlerCli = llm-agents.packages.${system}.but;
                };
                sharedModules = [
                  ./homes/modules
                  noctalia.homeModules.default
                ];
                useGlobalPkgs = true;
                useUserPackages = true;
                users.${user} = import homeModule;
              };
            }
            impermanence.nixosModules.impermanence
            hardwareModule
            noctalia-greeter.nixosModules.default
            sops-nix.nixosModules.sops
            stylix.nixosModules.stylix
          ]
          ++ extraModules;
          specialArgs = {
            inherit pkgsUnstable;
          };
        };
    in
    {
      checks.${system} = {
        pre-commit = preCommitCheck;
        host-invariants = import ./tests/host-invariants.nix {
          self = inputs.self or (throw "self input unavailable");
          pkgs = nixpkgs.legacyPackages.${system};
        };
        secure-uki-unit = nixpkgs.legacyPackages.${system}.callPackage ./pkgs/secure-uki { };
        secure-uki-pcr = import ./tests/secure-uki-pcr.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit disko impermanence;
        };
        secure-uki = import ./tests/secure-uki.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit disko impermanence;
        };
        secure-uki-module = import ./tests/secure-uki-module.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          impermanenceModule = impermanence.nixosModules.impermanence;
          fwupdPackage = inputs.self.nixosConfigurations.dancer.config.services.fwupd.package;
        };
        secure-uki-module-eval = import ./tests/secure-uki-module-eval.nix {
          dancer = inputs.self.nixosConfigurations.dancer;
          pkgs = nixpkgs.legacyPackages.${system};
          impermanenceModule = impermanence.nixosModules.impermanence;
          fwupdPackage = inputs.self.nixosConfigurations.dancer.config.services.fwupd.package;
        };
        secure-uki-publish = import ./tests/secure-uki-publish.nix {
          pkgs = nixpkgs.legacyPackages.${system};
        };
        secure-uki-probe = import ./tests/secure-uki-probe.nix {
          pkgs = nixpkgs.legacyPackages.${system};
        };
        fwupd-efi = import ./tests/fwupd-efi.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          fwupdPackage = inputs.self.nixosConfigurations.dancer.config.services.fwupd.package;
          fwupdTmpfilesRules = inputs.self.nixosConfigurations.dancer.config.systemd.tmpfiles.rules;
        };
        ssh-lan = import ./tests/ssh-lan.nix {
          inherit pkgsUnstable;
          pkgs = nixpkgs.legacyPackages.${system};
        };
        impermanence = import ./tests/impermanence.nix {
          inherit disko impermanence;
          pkgs = nixpkgs.legacyPackages.${system};
        };
      };

      nixosConfigurations = {
        kellanved = mkHost {
          name = "kellanved";
          hardwareModule = nixos-hardware.nixosModules.framework-13-7040-amd;
          homeModule = ./homes/roberto-at-kellanved;
        };
        dancer = mkHost {
          name = "dancer";
          hardwareModule = nixos-hardware.nixosModules.lenovo-thinkpad-x1;
          homeModule = ./homes/roberto-at-dancer;
        };
      };

    };
}
