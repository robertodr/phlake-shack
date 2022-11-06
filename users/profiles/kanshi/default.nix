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
            criteria = "Lenovo Group Limited Q27q-10 0x00000101";
            mode = "2560x1440";
            position = "0,0";
            scale = 1.0;
          }
        ];

        exec = [
          "${pkgs.sway}/bin/swaymsg workspace number 1, move workspace to '\"Lenovo Group Limited Q27q-10 0x00000101\"'"
          "${pkgs.sway}/bin/swaymsg workspace number 2, move workspace to '\"Lenovo Group Limited Q27q-10 0x00000101\"'"
          "${pkgs.sway}/bin/swaymsg workspace number 3, move workspace to eDP-1"
          "${pkgs.sway}/bin/swaymsg workspace number 4, move workspace to eDP-1"
        ];
      };

      kth = {
        outputs = [
          {
            criteria = "eDP-1";
            position = "2560,260";
            mode = "2256x1504";
            scale = 1.5;
          }
          {
            criteria = "ViewSonic Corporation VG2719-2K V4H174900131";
            mode = "2560x1440";
            position = "0,0";
            scale = 1.0;
          }
        ];

        exec = [
          "${pkgs.sway}/bin/swaymsg workspace number 1, move workspace to '\"ViewSonic Corporation VG2719-2K V4H174900131\"'"
          "${pkgs.sway}/bin/swaymsg workspace number 2, move workspace to '\"ViewSonic Corporation VG2719-2K V4H174900131\"'"
          "${pkgs.sway}/bin/swaymsg workspace number 3, move workspace to eDP-1"
          "${pkgs.sway}/bin/swaymsg workspace number 4, move workspace to eDP-1"
        ];
      };
    };
  };
}
