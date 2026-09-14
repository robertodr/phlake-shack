{
  config,
  lib,
  pkgs,
  ...
}:
let
  tomlFormat = pkgs.formats.toml { };

  piStarshipPatch = pkgs.writeShellApplication {
    name = "patch-pi-starship";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      agent_dir="''${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
      python3 - "$agent_dir" <<'PY'
      import os
      import pathlib
      import stat
      import sys

      chunks = pathlib.Path(sys.argv[1]) / "npm/node_modules/@narumitw/pi-starship/dist/chunks"
      if not chunks.is_dir():
          raise SystemExit(0)

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

      patched_count = 0

      for path in chunks.glob("*.js"):
          temporary = None
          try:
              source = path.read_text()
              relevant = "function parseToml" in source or (
                  '"smol-toml"' in source and "createRequire(import.meta.url)" in source
              )
              if not relevant:
                  continue
              if new_parser in source:
                  continue
              if old_parser in source:
                  if old_import not in source:
                      print(f"warning: pi-starship parser matched without its createRequire import: {path}", file=sys.stderr)
                      continue
                  updated = source.replace(old_import, new_import).replace(old_parser, new_parser)
                  temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
                  temporary.write_text(updated)
                  temporary.chmod(stat.S_IMODE(path.stat().st_mode))
                  os.replace(temporary, path)
                  temporary = None
                  patched_count += 1
                  continue
              if 'from "smol-toml"' in source and "createRequire(import.meta.url)" not in source:
                  continue
              print(f"warning: pi-starship's generated parser layout changed in {path}; verify whether the local patch is still needed.", file=sys.stderr)
          except (OSError, UnicodeError) as error:
              print(f"warning: unable to inspect or patch pi-starship chunk {path}: {error}", file=sys.stderr)
          finally:
              if temporary is not None:
                  try:
                      temporary.unlink(missing_ok=True)
                  except OSError as error:
                      print(f"warning: unable to clean temporary pi-starship chunk {temporary}: {error}", file=sys.stderr)

      if patched_count:
          print(f"Patched pi-starship TOML loading in {patched_count} chunk(s).", file=sys.stderr)
      PY
    '';
  };

  piWithStarshipPatch = pkgs.writeShellApplication {
    name = "pi";
    derivationArgs.meta = pkgs.llm-agents.pi.meta;
    text = ''
      patch_pi_starship() {
        ${lib.getExe piStarshipPatch} ||
          printf '%s\n' 'warning: unable to apply the local pi-starship compatibility patch' >&2
      }

      patch_pi_starship
      set +e
      ${lib.getExe pkgs.llm-agents.pi} "$@"
      status=$?
      set -e
      patch_pi_starship
      exit "$status"
    '';
  };
in
{
  programs.pi-coding-agent = {
    enable = true;
    package = piWithStarshipPatch;
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

  # Pi's bundled Node SEA extension loader cannot resolve pi-starship's lazy
  # createRequire("smol-toml") call even though npm installed the dependency.
  # Repair the generated chunk during activation and before and after every Pi
  # invocation, including package updates that overwrite it.
  home.activation.patchPiStarship = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PI_CODING_AGENT_DIR="${config.programs.pi-coding-agent.configDir}" \
      ${lib.getExe piStarshipPatch} ||
      printf '%s\n' 'warning: unable to apply the local pi-starship compatibility patch during activation' >&2
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
