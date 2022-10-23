{pkgs, ...}: {
  services.kanshi = {
    enable = true;

    profiles = {
      undocked = {
        outputs = [
          {
            criteria = "eDP-1";
            position = "0,0";
            mode = "2256x1504";
            scale = 1.5;
          }
        ];
      };

      docked = {
        outputs = [
          {
            criteria = "eDP-1";
            position = "2560,260";
            mode = "2256x1504";
            scale = 1.5;
          }
          {
            criteria = "DP-6";
            mode = "2560x1440";
            position = "0,0";
            scale = 1.0;
          }
        ];

        exec = [
          "${pkgs.sway}/bin/swaymsg workspace number 1, move workspace to DP-6"
          "${pkgs.sway}/bin/swaymsg workspace number 2, move workspace to DP-6"
          "${pkgs.sway}/bin/swaymsg workspace number 3, move workspace to eDP-1"
          "${pkgs.sway}/bin/swaymsg workspace number 4, move workspace to eDP-1"
        ];
      };
    };
  };
}
