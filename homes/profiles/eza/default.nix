{
  programs.eza = {
    enable = true;
    icons = "auto";
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
