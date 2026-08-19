{
  pkgs,
  lib,
  ...
}:
let
  # Merged into ~/.claude/settings.json by the activation script below rather
  # than declared via programs.claude-code.settings: Claude Code rewrites that
  # file itself (/model, /config), so a read-only store symlink would both
  # break those and abort HM's checkLinkTargets.
  statusLine = {
    type = "command";
    command = lib.getExe pkgs.llm-agents.ccstatusline;
    padding = 0;
    refreshInterval = 10;
  };

  # Written as a script so the jq redirection is not split from `run`, which
  # would otherwise clobber settings.json with the echoed command under
  # `nixos-rebuild dry-activate`.
  mergeStatusLine = pkgs.writeShellScript "claude-code-merge-statusline" ''
    set -euo pipefail
    settings="$HOME/.claude/settings.json"
    mkdir -p "$(dirname "$settings")"
    [ -s "$settings" ] || echo '{}' > "$settings"
    ${lib.getExe pkgs.jq} \
      --argjson statusLine '${builtins.toJSON statusLine}' \
      '.statusLine = $statusLine' \
      "$settings" > "$settings.hm-new"
    mv "$settings.hm-new" "$settings"
  '';
in
{
  programs.claude-code = {
    enable = true;
    package = pkgs.llm-agents.claude-code;
    context = ''
      If you make a commit, follow conventional commits and add a trailer:
      `Assisted-by: <harness>:<model>`, where `<harness>` is the current agent harness
      (like ClaudeCode), and `<model>` is the AI model (Like claude-opus-4.8). You
      don't need to add a coauthored-by Claude when you have this.

      Prefix PR descriptions and comments on PRs with the line ":robot: _AI text
      below_ :robot:" to indicate you are an agent speaking on a user's behalf.
    '';
  };

  home.activation.claudeCodeStatusLine = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${mergeStatusLine}
  '';

  xdg.configFile."ccstatusline/settings.json" = {
    # force: ccstatusline writes a default settings.json on first run if the file
    # is absent, which would otherwise abort HM's checkLinkTargets forever after.
    force = true;
    source = (pkgs.formats.json { }).generate "ccstatusline-settings.json" {
      version = 3;
      lines = [
        [
          {
            id = "1";
            type = "model";
            color = "cyan";
          }
          {
            id = "2";
            type = "thinking-effort";
          }
          {
            id = "3";
            type = "git-branch";
            color = "magenta";
          }
          {
            id = "4";
            type = "git-changes";
            color = "yellow";
          }
        ]
        [
          {
            id = "5";
            type = "context-bar";
            metadata.display = "progress-short";
          }
        ]
        [
          {
            id = "6";
            type = "current-working-dir";
            rawValue = true;
            metadata.fishStyle = "true";
          }
        ]
      ];
      flexMode = "full-until-compact";
      compactThreshold = 75;
      colorLevel = 2;
      defaultSeparator = "|";
      globalBold = true;
      gitCacheTtlSeconds = 5;
      powerline.enabled = false;
    };
  };
}
