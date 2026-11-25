{ pkgs, ... }:
{
  home.stateVersion = "24.11";
  home.packages = [ pkgs.oleafly ];

  profiles.agent-clis = {
    codeMode.enable = true;
    egm.enable = true;
    rtkHooks.enable = true;
  };

  programs = {
    claude-code.enable = true;
    codex.enable = true;
    antigravity-cli.enable = true;

    ssh.settings = {
      dancer.hostname = "dancer.tail99ea27.ts.net";
      dancer-lan = {
        hostname = "192.168.68.104";
        user = "roberto";
        forwardAgent = false;
      };
    };
  };

  imports = [
    ../profiles/base
    ../profiles/development
    ../profiles/desktop
    ../profiles/git/desktop.nix
    ../profiles/git/onepassword.nix
    ../profiles/ssh/onepassword.nix
    ../profiles/kenn-forge
  ];
}
