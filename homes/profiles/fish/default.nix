{ pkgs, ... }:
{
  programs.fish = {
    enable = true;

    plugins = [
      # a foreign environment interface for Fish shell
      {
        name = "foreign-env";
        src = pkgs.fishPlugins.foreign-env.src;
      }
    ];
  };
}
