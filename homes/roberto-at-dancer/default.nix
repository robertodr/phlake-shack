{
  config,
  lib,
  pkgs,
  ...
}:
let
  unlockKeyring = pkgs.writeShellApplication {
    name = "unlock-keyring";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      exec ${pkgs.python3}/bin/python3 -I ${./unlock-keyring.py} "$@"
    '';
  };
in
{

  imports = [
    ../profiles/base
    ../profiles/development
  ];

  home = {
    username = "roberto";
    homeDirectory = "/home/roberto";
    stateVersion = "26.05";
    packages = [
      pkgs.tmux
      unlockKeyring
    ];
    # Activation gates console login; do not fetch mutable npm updates at boot.
    # Update explicitly after login with: pi update --extensions
    activation.updatePiExtensions = lib.mkForce (lib.hm.dag.entryAfter [ "writeBoundary" ] "");
  };

  # Keep Dancer's explicit-update policy; Framework uses the background timer.
  systemd.user.timers.pi-update-extensions.Install.WantedBy = lib.mkForce [ ];

  services.ssh-agent.enable = true;

  profiles.agent-clis = {
    codeMode.enable = true;
    egm.enable = true;
    rtkHooks.enable = true;
  };

  programs = {
    codex.enable = true;
    antigravity-cli.enable = true;

    git.settings.user.signingkey = "${config.home.homeDirectory}/.ssh/git_signing_ed25519";

    # Distinguish the headless host in both local and SSH terminals.
    starship.settings = {
      format = lib.mkForce ''
        [┌─](bold blue) $username$hostname:$directory
        [│](bold blue) $time $battery$nix_shell$python$rust
        [└─](bold blue) $git_branch$git_state$git_status$character'';
      # SSH renders with the connecting terminal's font. Use text rather than
      # private-use glyphs; absent modules should leave no empty delimiters.
      nix_shell.symbol = lib.mkForce "nix ";
      python.symbol = lib.mkForce "py";
      rust.symbol = lib.mkForce "rs";
      git_branch.symbol = lib.mkForce "git:";
      git_branch.format = lib.mkForce "[$symbol$branch]($style) ";
      git_status = {
        format = lib.mkForce "($ahead_behind$staged$modified$untracked$deleted )";
        staged = lib.mkForce "[S$count](yellow)";
        modified = lib.mkForce "[M$count](green)";
        untracked = lib.mkForce "[?$count](blue)";
        deleted = lib.mkForce "[D$count](red)";
      };
      directory.read_only = " ro";
      battery = {
        format = "[bat $percentage]($style) ";
        display = [
          {
            threshold = 10;
            style = "bold red";
          }
          {
            threshold = 30;
            style = "bold yellow";
          }
          {
            threshold = 100;
            style = "bold cyan";
          }
        ];
      };
      username.style_user = lib.mkForce "bold cyan";
      hostname.format = lib.mkForce "[@](bold cyan)[$hostname](bold cyan)";
      directory.style = lib.mkForce "bold #5fafff";
      character.success_symbol = lib.mkForce "[>](bold cyan) ";
    };
  };

}
