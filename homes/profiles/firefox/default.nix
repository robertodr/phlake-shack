{pkgs, ...}: {
  programs.firefox = {
    enable = true;
    profiles = {
      default = {
        id = 0;
        name = "default";
        isDefault = true;
        settings = {
          "browser.search.defaultenginename" = "DuckDuckGo";
          "browser.search.order.1" = "DuckDuckGo";
          "browser.startup.homepage" = "https://duckduckgo.com";
          "browser.toolbars.bookmarks.visibility" = "always";
          "extensions.pocket.enabled" = "false";
          "font.name.serif.x-western" = "M PLUS 2 Regular";
        };
        search = {
          force = true;
          default = "DuckDuckGo";
          order = ["DuckDuckGo" "Google"];
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
            "NixOS Options" = {
              urls = [
                {
                  template = "https://search.nixos.org/options";
                  params = [
                    {
                      name = "type";
                      value = "options";
                    }
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = ["@no"];
            };
            "NixOS Wiki" = {
              urls = [{template = "https://wiki.nixos.org/w/index.php?search={searchTerms}";}];
              iconUpdateURL = "https://wiki.nixos.org/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000; # every day
              definedAliases = ["@nw"];
            };
            "Amazon".metaData.hidden = true;
            "Bing".metaData.hidden = true;
          };
        };
        extensions = with pkgs.nur.repos.rycee.firefox-addons; [
          c-c-search-extension
          darkreader
          decentraleyes
          joplin-web-clipper
          notion-web-clipper
          onepassword-password-manager
          paperpile
          privacy-badger
          redirector
          rust-search-extension
          side-view
          toggl-button-time-tracker
          ublock-origin
          unpaywall
        ];
      };
    };
  };
}
