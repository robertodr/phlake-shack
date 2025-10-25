{ pkgsUnstable, ... }:
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
}
