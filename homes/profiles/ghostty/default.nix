{ pkgsUnstable, ... }:
{
  programs.ghostty = {
    enable = true;
    package = pkgsUnstable.ghostty;
    installBatSyntax = true;
    installVimSyntax = true;
    settings = {
      gtk-tabs-location = "bottom";
      shell-integration-features = "ssh-terminfo,ssh-env";
      copy-on-select = true;
    };
    systemd.enable = true;
  };
}
