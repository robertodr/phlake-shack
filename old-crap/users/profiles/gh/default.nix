{pkgs, ...}: {
  programs.gh = {
    enable = true;
    # for inspiration: https://github.com/kodepandai/awesome-gh-cli-extensions
    # most of these need to be packaged!
    # gh-oblique gh-contrib gh-graph
    extensions = with pkgs; [gh-eco gh-cal gh-dash gh-actions-cache];
  };
}
