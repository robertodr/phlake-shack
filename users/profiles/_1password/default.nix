{
  # FIXME gid setting will be obsolete once this is merged: https://github.com/NixOS/nixpkgs/pull/172058
  programs = {
    _1password = {
      enable = true;
      gid = 31002;
    };

    _1password-gui = {
      enable = true;
      gid = 31001;
      # TODO is there a way to get the name?
      polkitPolicyOwners = [ "roberto" ];
    };
  };
}

