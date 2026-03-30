{ pkgs, pkgsUnstable, ... }:
{
  programs = {
    _1password = {
      enable = true;
      package = pkgsUnstable._1password-cli;
    };

    _1password-gui = {
      enable = true;
      package = pkgsUnstable._1password-gui;
      polkitPolicyOwners = [ "roberto" ];
    };
  };

  environment.etc = {
    "1password/custom_allowed_browsers" = {
      text = ''
        vivaldi-bin
      '';
      mode = "0755";
    };
  };
}
