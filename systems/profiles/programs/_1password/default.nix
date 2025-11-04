{ pkgs, pkgsUnstable, ... }:
{
  programs = {
    _1password = {
      enable = true;
      package = pkgsUnstable._1password-cli;
    };

    _1password-gui = {
      enable = true;
      package = pkgsUnstable._1password-gui-beta;
      polkitPolicyOwners = [ "roberto" ];
    };
  };

  systemd.user = {
    services = {
      # needed to get 1password to use system authentication correctly:
      # https://1password.community/discussion/comment/634787/#Comment_634787
      polkit-gnome-authentication-agent-1 = {
        description = "polkit-gnome-authentication-agent-1";
        wantedBy = [ "graphical-session.target" ];
        wants = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 10;
        };
      };
    };
  };
}
