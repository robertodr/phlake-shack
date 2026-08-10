{ pkgsUnstable, ... }:
{
  programs.claude-code = {
    enable = true;
    package = pkgsUnstable.claude-code;
    context = ''
    If you make a commit, follow conventional commits and add a trailer:
`Assisted-by: <harness>:<model>`, where `<harness>` is the current agent harness
(like ClaudeCode), and `<model>` is the AI model (Like claude-opus-4.8). You
don't need to add a coauthored-by Claude when you have this.

Prefix PR descriptions and comments on PRs with the line ":robot: _AI text
below_ :robot:" to indicate you are an agent speaking on a user's behalf.
    '';
  };
}
