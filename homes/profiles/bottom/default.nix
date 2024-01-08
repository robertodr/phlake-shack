{
  programs.bottom = {
    enable = true;
    settings = {
      flags = {
        battery = true;
      };
    };
  };

  home.shellAliases = {
    top = "btm";
    htop = "btm";
  };
}
