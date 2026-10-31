{
  description = "My NixOS systems and Home Manager configurations";

  inputs = {
    bun2nix = {
      url = "github:nix-community/bun2nix?ref=2.1.2";
    };

    deploy-rs = {
      # Match the cached deploy/activate binary in the existing nixpkgs pin.
      url = "github:serokell/deploy-rs?rev=e760371d631165e7d8de5b0dcf148e21ec4c16f0";
      inputs.nixpkgs.follows = "nixpkgs";
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
      deploy-rs,
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

      # Deployment tooling only: do not add this overlay to either host.
      deployPkgs = import nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlays.default
          (_final: prev: {
            deploy-rs = {
              deploy-rs = nixpkgs.legacyPackages.${system}.deploy-rs;
              inherit (prev.deploy-rs) lib;
            };
          })
        ];
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

      # Internal base for storage comparisons; the public hostname-selected
      # target always adds the manual-LUKS policy.
      dancerBase = mkHost {
        name = "dancer";
        hardwareModule = nixos-hardware.nixosModules.lenovo-thinkpad-x1;
        homeModule = ./homes/roberto-at-dancer;
      };
    in
    {
      apps.${system}.deploy = {
        type = "app";
        program = "${deployPkgs.deploy-rs.deploy-rs}/bin/deploy";
      };

      deploy.nodes.dancer = {
        hostname = "192.168.68.104";
        sshUser = user;
        user = "root";
        # Custom sudo must consume the password deploy-rs sends over stdin.
        sudo = "/run/wrappers/bin/sudo -S -p '' -u";
        interactiveSudo = true;
        sshOpts = [
          "-o"
          "ForwardAgent=no"
        ];
        remoteBuild = true;
        autoRollback = true;
        magicRollback = true;
        profiles.system = {
          profilePath = "/nix/var/nix/profiles/system";
          path = deployPkgs.deploy-rs.lib.activate.nixos inputs.self.nixosConfigurations.dancer;
        };
      };

      checks.${system} = {
        # Schema validation needs path strings, not a local build of Dancer.
        deploy-schema =
          (deployPkgs.deploy-rs.lib.deployChecks (
            builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.toJSON inputs.self.deploy))
          )).deploy-schema;
        # Full-profile realization: deliberately not part of local prechecks.
        deploy-activate = (deployPkgs.deploy-rs.lib.deployChecks inputs.self.deploy).deploy-activate;
        pre-commit = preCommitCheck;
        deploy-rs-eval = import ./tests/deploy-rs-eval.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          self = inputs.self;
        };
        starship-battery-eval = import ./tests/starship-battery-eval.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (inputs.self.nixosConfigurations) dancer kellanved;
        };
        host-invariants = import ./tests/host-invariants.nix {
          self = inputs.self or (throw "self input unavailable");
          pkgs = nixpkgs.legacyPackages.${system};
        };
        dancer-manual-boot-eval = import ./tests/dancer-manual-boot-eval.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (inputs.self.nixosConfigurations) dancer kellanved;
          manualDancer = inputs.self.nixosConfigurations.dancer-manual-boot;
          baseDancer = dancerBase;
          hasManualTarget = true;
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
        dancer = dancerBase.extendModules {
          modules = [ ./systems/profiles/boot/manual-luks ];
        };
        # Compatibility name for the original rollback target; no separate policy.
        dancer-manual-boot = inputs.self.nixosConfigurations.dancer;
      };

    };
}
