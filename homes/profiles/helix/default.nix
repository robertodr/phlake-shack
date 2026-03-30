{pkgs, pkgsUnstable, ...} : {
  programs.helix = {
    enable = true;
    defaultEditor = true;
    #extraPackages = [];
    #languages = {};
  };
}
