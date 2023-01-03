{...}: {
  programs.gh = {
    enable = true;
    # for inspiration: https://github.com/kodepandai/awesome-gh-cli-extensions
    # most of these need to be packaged!
    # extension = with pkgs; [ gh-eco gh-oblique gh-contrib gh-graph ];
  };
}
