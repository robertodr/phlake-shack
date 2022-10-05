{pkgs, ...}: {
  home.packages = with pkgs; [
    #nur.repos.robertodr.git-along
    bastet
    kitty
    brave
  ];
}
