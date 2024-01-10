{pkgs, ...}: {
  programs.fish = {
    enable = true;

    plugins = [
      # keeps your fish shell history clean from typos, incorrectly used commands and everything you don't want to store due to privacy reasons
      {
        name = "sponge";
        src = pkgs.fishPlugins.sponge.src;
      }

      # automatically receive notifications when long processes finish
      {
        name = "done";
        src = pkgs.fishPlugins.done.src;
      }

      # a utility tool powered by fzf for using git interactively
      {
        name = "forgit";
        src = pkgs.fishPlugins.forgit.src;
      }

      # augment your fish command line with fzf key bindings
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }

      # a foreign environment interface for Fish shell
      {
        name = "foreign-env";
        src = pkgs.fishPlugins.foreign-env.src;
      }
    ];
  };
}
