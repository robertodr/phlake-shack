{
  description = "A highly structured configuration database.";

  nixConfig.extra-experimental-features = "nix-command flakes";
  nixConfig.extra-substituters = [
    "https://nrdxp.cachix.org"
    "https://nix-community.cachix.org"
  ];
  nixConfig.extra-trusted-public-keys = [
    "nrdxp.cachix.org-1:Fc5PSqY2Jm1TrWfm88l6cvGWwz3s93c6IOifQWnhNW4="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  inputs = {
    # Track channels with commits tested and built by hydra
    nixos.url = "github:nixos/nixpkgs/nixos-22.11";
    latest.url = "github:nixos/nixpkgs/nixos-unstable";

    home = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "latest";
    };

    nixos-hardware.url = "github:nixos/nixos-hardware";

    digga = {
      url = "github:divnix/digga";
      inputs = {
        nixpkgs.follows = "nixos";
        nixlib.follows = "nixos";
        home-manager.follows = "home";
      };
    };

    # bleeding edge emacs overlay
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay?rev=88b2e9eda133e593558680ffb6262203db193ac4";
      inputs.nixpkgs.follows = "latest";
    };

    # age-encrypted secrets for NixOS
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixos";
    };

    # NUR packages
    nur.url = "github:nix-community/NUR";

    base16-schemes = {
      url = github:base16-project/base16-schemes;
      flake = false;
    };

    stylix = {
      url = "github:danth/stylix";
      inputs = {
        nixpkgs.follows = "latest";
        home-manager.follows = "home";
      };
    };
  };

  outputs = {
    self,
    digga,
    nixos,
    home,
    nixos-hardware,
    nur,
    agenix,
    nixpkgs,
    emacs-overlay,
    stylix,
    ...
  } @ inputs:
    digga.lib.mkFlake
    {
      inherit self inputs;

      supportedSystems = [
        "x86_64-linux"
        # "aarch64-linux"
      ];

      channelsConfig = {allowUnfree = true;};

      channels = {
        nixos = {
          imports = [(digga.lib.importOverlays ./overlays)];
          overlays = [];
        };
        latest = {
          overlays = [
          ];
        };
      };

      lib = import ./lib {lib = digga.lib // nixos.lib;};

      sharedOverlays = [
        (final: prev: {
          __dontExport = true;
          lib = prev.lib.extend (lfinal: lprev: {
            our = self.lib;
          });
        })

        nur.overlay
        agenix.overlays.default
        emacs-overlay.overlay

        (import "${fetchTarball {
          url = "https://github.com/vlaci/openconnect-sso/archive/master.tar.gz";
          sha256 = "sha256:04kwar7cxz7399bwlka6raqwq5jd27khkjdxk11k08846bkjckx5";
        }}/overlay.nix")

        (import ./pkgs)
      ];

      nixos = {
        hostDefaults = {
          system = "x86_64-linux";
          channelName = "nixos";
          imports = [(digga.lib.importExportableModules ./modules)];
          modules = [
            {lib.our = self.lib;}
            digga.nixosModules.bootstrapIso
            digga.nixosModules.nixConfig
            home.nixosModules.home-manager
            agenix.nixosModules.age
            stylix.nixosModules.stylix
          ];
        };

        imports = [(digga.lib.importHosts ./hosts)];
        hosts = {
          # set host-specific properties here
          captain-easychord = {
            system = "x86_64-linux";
            channelName = "latest";
            modules = [nixos-hardware.nixosModules.framework-12th-gen-intel];
          };
        };
        importables = rec {
          profiles =
            digga.lib.rakeLeaves ./profiles
            // {
              users = digga.lib.rakeLeaves ./users;
            };
          # suites provide a mechanism for users to easily combine and name collections of profiles
          suites = nixos.lib.fix (suites: {
            nix-settings = with profiles.nix; [cachix gc settings];

            base =
              suites.nix-settings
              ++ (with profiles; [
                core
                fonts.common
                hardware.bluetooth
                networking
                programs._1password
                programs.gnupg
                programs.thunar
                services.earlyoom
                services.fwupd
                services.geoclue2
                services.gnome-keyring
                services.hardware.bolt
                services.languagetool
                services.openssh
                services.thermald
                services.udisks2
                systemd
                users.root
                zsa
              ]);

            i3wm = with profiles; [
              programs.dconf
              services.blueman
              services.dbus
              services.upower
              services.xserver
            ];

            swaywm = with profiles; [
              programs.sway
              programs.dconf
              services.blueman
              services.dbus
              services.greetd
              services.upower
            ];

            # TODO add borgbackup service
            backup = with profiles; [
              services.borgbackup
            ];

            multimedia = with profiles; [
              services.pipewire
              services.printing
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
        imports = [(digga.lib.importExportableModules ./users/modules)];
        modules = [
          # TODO nix flake show broken due to IFD
          # see https://github.com/nix-community/home-manager/issues/1262
          {manual.manpages.enable = false;}
        ];
        importables = rec {
          profiles = digga.lib.rakeLeaves ./users/profiles;
          # suites provide a mechanism for users to easily combine and name collections of profiles
          suites = nixos.lib.fix (suites: {
            base = with profiles; [
              bat
              blueman-applet
              bottom
              core
              exa
              fish
              fzf
              git
              gpg-agent
              gnome-keyring
              jq
              man
              neovim
              ssh
              starship
              tealdeer
              tmux
              udiskie
              wezterm
              zellij
              zoxide
            ];

            development = with profiles; [
              direnv
              emacs
              gh
              nix-index
              tmpi
              vscode
            ];

            multimedia = with profiles; [
              brave
              flameshot
              mpris-proxy
              obs-studio
            ];

            office = with profiles; [
              newsboat
              pandoc
              texlive
            ];

            i3wm = with profiles; [
              autorandr
              betterlockscreen
              dunst
              feh
              gtk
              picom
              polybar
              redshift
              rofi
              screen-locker
              xsession
            ];

            swaywm = with profiles; [
              gammastep
              gtk
              kanshi
              swayidle
              swaylock
              waybar
              wayland
            ];

            synchronize = with profiles; [
              syncthing
            ];
          });
        };
        users = {
          roberto = {suites, ...}: {imports = with suites; base ++ development ++ multimedia ++ office ++ swaywm ++ synchronize;};
        }; # digga.lib.importers.rakeLeaves ./users/hm;
      };

      devshell = ./shell;

      homeConfigurations =
        digga.lib.mergeAny
        (digga.lib.mkHomeConfigurations self.nixosConfigurations);
    };
}
