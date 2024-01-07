{pkgs, ...}: {
  programs.fish = {
    enable = true;

    plugins = [
      {
        name = "sponge";
        src = pkgs.fetchFromGitHub {
          owner = "andreiborisov";
          repo = "sponge";
          rev = "dcfcc9089939f48b25b861a9254a39de8e9f33a0";
          sha256 = "+GGfFC/hH7A8n9Wwojt5PW96fSzvRhThnZ3pLeWEqds=";
        };
      }

      {
        name = "fish-abbreviation-tips";
        src = pkgs.fetchFromGitHub {
          owner = "gazorby";
          repo = "fish-abbreviation-tips";
          rev = "5bca1e03beda87b7494a9ffbd6b696dc78ed03f6";
          sha256 = "jQSG7N9awd99TzYXAqguS0K0R38B9ytmtZuPCNSWz8A=";
        };
      }

      {
        name = "done";
        src = pkgs.fishPlugins.done.src;
      }

      {
        name = "forgit";
        src = pkgs.fishPlugins.forgit.src;
      }

      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }

      {
        name = "foreign-env";
        src = pkgs.fishPlugins.foreign-env.src;
      }
    ];

    shellAliases = {
      cat = "bat";
      #ls = "eza -bghluHS --git";
      xopen = "xdg-open";
    };
  };
}
