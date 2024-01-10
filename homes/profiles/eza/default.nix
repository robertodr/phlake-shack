{
  programs.eza = {
    enable = true;
    enableAliases = true;
    icons = true;
    git = true;
    extraOptions = [
      "--long"
      "--binary"
      "--header"
      "--smart-group"
      "--accessed"
      "--group-directories-first"
    ];
  };
}
