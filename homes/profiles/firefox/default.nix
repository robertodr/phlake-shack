{pkgs, ...}: {
  programs.firefox = {
    enable = true;
    profiles = {
      default = {
        id = 0;
        name = "default";
        isDefault = true;
        settings = {
          "browser.startup.homepage" = "https://searx.aicampground.com";
          "browser.search.defaultenginename" = "Searx";
          "browser.search.order.1" = "Searx";
        };
        search = {
          force = true;
          default = "Searx";
          order = ["Searx" "DuckDuckGo" "Google"];
          engines = {
            "Nix Packages" = {
              urls = [
                {
                  template = "https://search.nixos.org/packages";
                  params = [
                    {
                      name = "type";
                      value = "packages";
                    }
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = ["@np"];
            };
            "NixOS Wiki" = {
              urls = [{template = "https://nixos.wiki/index.php?search={searchTerms}";}];
              iconUpdateURL = "https://nixos.wiki/favicon.png";
              updateInterval = 24 * 60 * 60 * 1000; # every day
              definedAliases = ["@nw"];
            };
            "Searx" = {
              urls = [{template = "https://searx.aicampground.com/?q={searchTerms}";}];
              iconUpdateURL = "https://nixos.wiki/favicon.png";
              updateInterval = 24 * 60 * 60 * 1000; # every day
              definedAliases = ["@searx"];
            };
            "Bing".metaData.hidden = true;
            "Google".metaData.alias = "@g"; # builtin engines only support specifying one additional alias
          };
        };
        extensions = with pkgs.nur.repos.rycee.firefox-addons; [
          # the paperpile extension is not yet available, so remember to install it by hand
          c-c-search-extension
          darkreader
          decentraleyes
          joplin-web-clipper
          notion-web-clipper
          onepassword-password-manager
          privacy-badger
          ublock-origin
        ];
      };
    };
  };
}