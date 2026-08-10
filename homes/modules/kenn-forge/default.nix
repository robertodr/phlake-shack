{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.kenn-forge;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.services.kenn-forge = {
    enable = lib.mkEnableOption "kenn-forge";

    package = lib.mkPackageOption pkgs "kenn-forge" { };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = tomlFormat.type;

        options = {
          sync_interval = lib.mkOption {
            type = lib.types.str;
            default = "5m";
            description = "How often to pull from configured providers.";
          };

          github_token_env = lib.mkOption {
            type = lib.types.str;
            default = "KENN_FORGE_GITHUB_TOKEN";
            description = "Environment variable holding the default GitHub token.";
          };

          default_platform_host = lib.mkOption {
            type = lib.types.str;
            default = "github.com";
            description = "Host treated as implicit in repository UI labels.";
          };

          host = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "Listen address.";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 8091;
            description = "Listen port.";
          };

          base_path = lib.mkOption {
            type = lib.types.str;
            default = "/";
            description = "URL prefix for reverse proxy deployments.";
          };

          data_dir = lib.mkOption {
            type = lib.types.str;
            default = "${config.home.homeDirectory}/.kenn/forge";
            defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/.kenn/forge"'';
            description = ''
              Directory for the SQLite database.

              Must be an absolute path: kenn-forge resolves `data_dir` with
              `filepath.Abs` and never expands `~`, so a leading tilde would
              create a directory literally named `~` under the working
              directory.
            '';
          };

          repos = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                freeformType = tomlFormat.type;

                options = {
                  owner = lib.mkOption {
                    type = lib.types.str;
                    description = "Repository owner or namespace.";
                  };

                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "Repository name.";
                  };

                  platform = lib.mkOption {
                    type = lib.types.nullOr (
                      lib.types.enum [
                        "github"
                        "gitlab"
                        "forgejo"
                        "gitea"
                      ]
                    );
                    default = null;
                    description = "Provider platform type.";
                  };

                  platform_host = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Provider host for this repository.";
                  };

                  token_env = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Environment variable holding the token for this repo's host.";
                  };

                  repo_path = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Full path for the repository (useful for nested namespaces).";
                  };
                };
              }
            );
            default = [ ];
            description = "List of repositories to sync.";
          };

          platforms = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                freeformType = tomlFormat.type;

                options = {
                  type = lib.mkOption {
                    type = lib.types.enum [
                      "github"
                      "gitlab"
                      "forgejo"
                      "gitea"
                    ];
                    description = "Platform type.";
                  };

                  host = lib.mkOption {
                    type = lib.types.str;
                    description = "Platform host.";
                  };

                  token_env = lib.mkOption {
                    type = lib.types.str;
                    description = "Environment variable holding the token for this platform.";
                  };
                };
              }
            );
            default = [ ];
            description = "Platform host definitions for non-default providers.";
          };

          activity = lib.mkOption {
            type = lib.types.submodule {
              freeformType = tomlFormat.type;

              options = {
                view_mode = lib.mkOption {
                  type = lib.types.enum [
                    "flat"
                    "threaded"
                  ];
                  default = "threaded";
                  description = "Activity feed view mode.";
                };

                time_range = lib.mkOption {
                  type = lib.types.enum [
                    "24h"
                    "7d"
                    "30d"
                    "90d"
                  ];
                  default = "7d";
                  description = "Activity feed time range.";
                };

                hide_closed = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Hide closed/merged items in the feed.";
                };

                hide_bots = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Hide bot activity.";
                };
              };
            };
            default = { };
            description = "Activity feed settings.";
          };

          terminal = lib.mkOption {
            type = lib.types.submodule {
              freeformType = tomlFormat.type;

              options = {
                renderer = lib.mkOption {
                  type = lib.types.enum [
                    "xterm"
                    "ghostty-web"
                  ];
                  default = "xterm";
                  description = "Terminal renderer.";
                };
              };
            };
            default = { };
            description = "Terminal settings.";
          };
        };
      };
      default = { };
      description = ''
        Configuration for kenn-forge. Generates ~/.kenn/forge/config.toml.
        See https://github.com/kenn-io/forge/blob/main/docs/configuration.md for all options.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to an environment file containing secrets (e.g. KENN_FORGE_GITHUB_TOKEN=ghp_...).
        Loaded by the systemd service via EnvironmentFile.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file.".kenn/forge/config.toml".source =
      let
        removeNulls = lib.filterAttrs (_: v: v != null);
        settings = cfg.settings // {
          repos = map removeNulls cfg.settings.repos;
          platforms = map removeNulls cfg.settings.platforms;
        };
      in
      tomlFormat.generate "kenn-forge-config.toml" settings;

    systemd.user.services.kenn-forge = {
      Unit = {
        Description = "Kenn Forge - local-first maintainer console";
        After = [ "network-online.target" ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        RestartSec = 5;
      }
      // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };
  };
}
