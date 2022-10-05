{
  programs = {
    _1password = {
      enable = true;
    };

    _1password-gui = {
      enable = true;
      # TODO is there a way to get the name?
      polkitPolicyOwners = [ "roberto" ];
    };
  };
}
