{
  programs.atuin = {
    enable = true;
    daemon.enable = true;
    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      sync_address = "https://api.atuin.sh";
      search_mode = "fuzzy";
      enter_accept = false;
      update_check = false;
      sync = {
        records = true;
      };
    };
  };
}
