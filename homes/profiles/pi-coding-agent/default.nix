{
  config,
  lib,
  pkgs,
  ...
}:
let
  tomlFormat = pkgs.formats.toml { };
in
{
  programs.pi-coding-agent = {
    enable = true;
    package = pkgs.llm-agents.pi;
    context = ''
      If you make a commit, follow conventional commits and add a trailer:
      `Assisted-by: <harness>:<model>`, where `<harness>` is the current agent harness
      (like Pi), and `<model>` is the AI model (Like claude-opus-4.8). You
      don't need to add a coauthored-by when you have this.

      Prefix PR descriptions and comments on PRs with the line ":robot: _AI text
      below_ :robot:" to indicate you are an agent speaking on a user's behalf.
    '';
    extraPackages = [
      pkgs.nodejs
      pkgs.bun
    ];
    settings = {
      packages = [
        "npm:@narumitw/pi-starship@0.54.0"
        "npm:@termdraw/pi"
        "npm:pi-diff-review"
        "npm:pi-mcp-adapter"
      ];
      defaultModel = "gpt-5.6-sol";
      defaultProvider = "openai-codex";
      defaultThinkingLevel = "medium";
    };
  };

  # pi is a Bun-compiled executable. Bun cannot resolve pi-starship's lazy
  # createRequire("smol-toml") call even though npm installed the dependency.
  # Replace it with a regular ESM import, which Pi's extension loader resolves.
  home.activation.patchPiStarship = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    starship_chunks="${config.programs.pi-coding-agent.configDir}/npm/node_modules/@narumitw/pi-starship/dist/chunks"
    if [ -d "$starship_chunks" ]; then
      ${pkgs.python3}/bin/python3 - "$starship_chunks" <<'PY'
    import pathlib
    import sys

    chunks = pathlib.Path(sys.argv[1])
    old_import = 'import { createRequire } from "node:module";'
    new_import = 'import { parse as parseSmolToml } from "smol-toml";'
    old_parser = """var require2 = createRequire(import.meta.url);
    var parseTomlImplementation;
    function parseToml(document) {
      parseTomlImplementation ??= require2("smol-toml").parse;
      return parseTomlImplementation(document);
    }"""
    new_parser = """function parseToml(document) {
      return parseSmolToml(document);
    }"""

    for path in chunks.glob("*.js"):
        source = path.read_text()
        if old_parser not in source:
            continue
        path.write_text(source.replace(old_import, new_import).replace(old_parser, new_parser))
        break
    PY
    fi
  '';

  home.file."${config.programs.pi-coding-agent.configDir}/pi-starship.toml".source =
    tomlFormat.generate "pi-starship.toml"
      {
        format = "$brand$turn$activity$context$tokens$cost$time$provider$model$thinking$directory$git_branch$git_status";

        provider.format = "[ $provider ]($style)";

        model = {
          format = "[ $model ]($style)";
          style = "bold blue";
          truncation_length = 36;
          truncation_symbol = "…";
          truncation_direction = "middle";
        };

        directory.style = "cyan bold";
        git_branch.style = "bold purple";

        context = {
          format = "[$symbol $percentage/$window ]($style)";
          display = [
            {
              threshold = 0;
              style = "bold green";
              hidden = false;
            }
            {
              threshold = 30;
              style = "bold green";
              hidden = false;
            }
            {
              threshold = 60;
              style = "bold yellow";
              hidden = false;
            }
            {
              threshold = 80;
              style = "bold red";
              hidden = false;
            }
          ];
        };

        git_metrics = {
          added_style = "bold green";
          deleted_style = "bold red";
          disabled = false;
        };

        username = {
          style_user = "yellow bold";
          style_root = "red bold";
        };

        extension_status = {
          format = "([$statuses ]($style))";
          icons = {
            "foo:*" = "🧪";
            "third_party/key" = "◎";
            fallback = "•";
          };
        };
      };
}
