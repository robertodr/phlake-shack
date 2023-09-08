{
  inputs,
  pkgs,
  ...
}: {
  stylix = {
    image = pkgs.fetchurl {
      url = "https://www.pixelstalk.net/wp-content/uploads/2016/10/Paint-pattern-colored-abstract-background.jpg";
      sha256 = "sha256-kEdO+d3LXsRQdyyKck4YTkkwqz//CK8Z+RzXC9DSIpw=";
    };

    base16Scheme = "${inputs.base16-schemes}/helios.yaml";

    polarity = "dark";

    fonts = {
      serif = {
        name = "Gentium";
        package = pkgs.gentium;
      };

      sansSerif = {
        name = "M PLUS 2";
        package = pkgs.nur.repos.robertodr.mplus-fonts;
      };

      monospace = {
        name = "Fira Code Retina";
        package =
          pkgs.nerdfonts.override {fonts = ["FiraCode"];};
      };

      emoji = {
        name = "Noto Color Emoji";
        package = pkgs.noto-fonts-emoji;
      };

      sizes = {
        desktop = 12;
        applications = 14;
        terminal = 14;
        popups = 12;
      };
    };

    opacity = {
      popups = 0.50;
      desktop = 0.90;
    };

    targets = {
      grub.enable = false;
    };
  };

  home-manager.users.roberto = {
    stylix.targets = {
      emacs.enable = false;
      vscode.enable = false;
      # I prefer to do it explicitly!
      waybar.enable = false;
    };
  };
}
