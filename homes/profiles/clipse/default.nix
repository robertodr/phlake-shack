# FIXME this is a simplification of the module in https://github.com/nix-community/home-manager/pull/5777
{pkgs, ...}: let
  clipsePkg = pkgs.clipse;
  jsonFormat = pkgs.formats.json {};
in {
  home.packages = [
    clipsePkg
  ];

  xdg.configFile."clipse/config.json".source = jsonFormat.generate "settings" {
    allowDuplicates = false;
    historyFile = "clipboard_history.json";
    maxHistory = 100;
    logFile = "clipse.log";
    themeFile = "custom_theme.json";
    tempDir = "tmp_files";
    imageDisplay = {
      type = "kitty";
      scaleX = 9;
      scaleY = 9;
      heightCut = 2;
    };
  };

  xdg.configFile."clipse/custom_theme.json".source = jsonFormat.generate "theme" ''
    {
        useCustomTheme= false;
        DimmedDesc= "#ffffff";
        DimmedTitle= "#ffffff";
        FilteredMatch= "#ffffff";
        NormalDesc= "#ffffff";
        NormalTitle= "#ffffff";
        SelectedDesc= "#ffffff";
        SelectedTitle= "#ffffff";
        SelectedBorder= "#ffffff";
        SelectedDescBorder= "#ffffff";
        TitleFore= "#ffffff";
        Titleback= "#434C5E";
        StatusMsg= "#ffffff";
        PinIndicatorColor= "#ff0000";
    }
  '';

  systemd.user.services.clipse = {
    Unit = {
      Description = "Clipse listener";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${clipsePkg}/bin/clipse -listen";
    };

    Install = {WantedBy = ["graphical-session.target"];};
  };
}
