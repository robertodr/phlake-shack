{
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
{
  programs.claude-code = {
    enable = true;
    package = pkgsUnstable.claude-code;
    settings.statusLine = {
      type = "command";
      command = lib.getExe pkgs.ccstatusline;
      padding = 0;
      refreshInterval = 10;
    };
    context = ''
      If you make a commit, follow conventional commits and add a trailer:
      `Assisted-by: <harness>:<model>`, where `<harness>` is the current agent harness
      (like ClaudeCode), and `<model>` is the AI model (Like claude-opus-4.8). You
      don't need to add a coauthored-by Claude when you have this.

      Prefix PR descriptions and comments on PRs with the line ":robot: _AI text
      below_ :robot:" to indicate you are an agent speaking on a user's behalf.
    '';
  };

  xdg.configFile."ccstatusline/settings.json".source =
    (pkgs.formats.json { }).generate "ccstatusline-settings.json"
      {
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
}
