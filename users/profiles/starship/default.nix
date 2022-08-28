{ ... }:

{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = false;
      format = ''[┌─](bold) $username$hostname:$directory
[│](bold) $time \[$nix_shell$python$rust\]
[└─](bold) 美男象 \($git_branch$git_state$git_status\) $character'';
      scan_timeout = 10;
      character = {
        success_symbol = "[](bold green) ";
        error_symbol = "[](bold red) ";
      };
      directory = {
        truncate_to_repo = false;
        format = "[$path]($style)[$read_only]($read_only_style)";
        style = "bold #87ff00";
        truncation_symbol = "~/";
        fish_style_pwd_dir_length = 1;
      };
      git_branch = {
        style = "#5fdfff";
        symbol = "";
        format = "$symbol[$branch]($style)";
      };
      git_status = {
        format = "$ahead_behind|$staged$modified$untracked$deleted";
        ahead = "[↑$count](#df5f00)";
        behind = "[↓$count](#df005f)";
        deleted = "[﯊\($count\)](red)";
        diverged = "[⇕↑$\{ahead_count\}↓$\{behind_count\}](bold red)";
        staged = "[\($count\)](yellow)";
        modified = "[\($count\)](green)";
        untracked = "[\($count\)](blue)";
      };
      hostname = {
        ssh_only = false;
        format = "[@](bold)[$hostname](bold #df5f00)";
        disabled = false;
      };
      nix_shell = {
        symbol = "";
        format = "+[$symbol]($style)";
      };
      python = {
        symbol = "";
        format = "+[$symbol \($version\)]($style)";
      };
      rust = {
        symbol = "";
        format = "+[$symbol \($version\)]($style)";
      };
      time = {
        disabled = false;
        format = "[$time]($style)";
        time_format = "%a, %b %d %Y - %T";
      };
      username = {
        style_user = "bold #df005f";
        style_root = "bold red";
        format = "[$user]($style)";
        disabled = false;
        show_always = true;
      };
    };
  };
}
