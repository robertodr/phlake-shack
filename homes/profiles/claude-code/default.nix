{
  config,
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
  # Rolling back does not undo writable settings: back them up, then remove
  # only this generation's RTK command (never restore stale settings wholesale).
  mergeStatusLine = pkgs.writeShellScript "claude-code-merge-statusline" ''
    set -euo pipefail
    umask 077
    settings="$HOME/.claude/settings.json"
    mkdir -p "$(dirname "$settings")"
    input="$settings"
    [ -s "$input" ] || input=${pkgs.writeText "empty-settings.json" "{}"}
    tmp=$(mktemp "$settings.hm-XXXXXXXX")
    trap 'rm -f "$tmp"' EXIT
    ${lib.getExe pkgs.jq} \
      --argjson statusLine '${builtins.toJSON statusLine}' \
      ${
        if config.profiles.agent-clis.rtkHooks.enable then
          "--arg rtkCommand '${lib.getExe pkgs.llm-agents.rtk} hook claude' -f ${./rtk-hooks.jq}"
        else
          "'.statusLine = $statusLine'"
      } \
      "$input" > "$tmp"
    mv "$tmp" "$settings"
  '';
in
lib.mkIf config.programs.claude-code.enable {
  programs.claude-code.package = pkgs.llm-agents.claude-code;

  home.activation.claudeCodeStatusLine = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${mergeStatusLine}
  '';

  xdg.configFile."ccstatusline/settings.json" = {
    # force: ccstatusline writes a default settings.json on first run if the file
    # is absent, which would otherwise abort HM's checkLinkTargets forever after.
    # Darwin adopts existing dotfiles explicitly; preserve Linux's overwrite policy.
    force = pkgs.stdenv.hostPlatform.isLinux;
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
