{
  programs.eza = {
    enable = true;
    enableAliases = true;
    git = true;
    # home-manager makes a mess with quotes generating this alias for fish
    # it's added under programs.fish.shellAliases
    #extraOptions = [
    #  "--binary"
    #  "--header"
    #  "--smart-group"
    #  "--accessed"
    #  "--group-directories-first"
    #];
  };
}
