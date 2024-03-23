{pkgs, ...}: {
  programs.gh = {
    enable = true;
    extensions = with pkgs; [gh-dash gh-actions-cache unstable.gh-copilot];
  };
}
