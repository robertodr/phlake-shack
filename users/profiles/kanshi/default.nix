{pkgs, ...}: {
  home.packages = [
    pkgs.wdisplays
  ];

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
            mode = "2256x1504";
            position = "2560,260";
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
            mode = "2256x1504";
            position = "2560,260";
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

      tromso = {
        outputs = [
          {
            criteria = "eDP-1";
            mode = "2256x1504";
            position = "2560,260";
            scale = 1.5;
          }
          {
            criteria = "Dell Inc. DELL C2722DE F4FNZG3";
            mode = "2560x1440";
            position = "0,0";
            scale = 1.0;
          }
        ];

        exec = [
          "${pkgs.sway}/bin/swaymsg workspace number 1, move workspace to '\"Dell Inc. DELL C2722DE F4FNZG3\"'"
          "${pkgs.sway}/bin/swaymsg workspace number 2, move workspace to '\"Dell Inc. DELL C2722DE F4FNZG3\"'"
          "${pkgs.sway}/bin/swaymsg workspace number 3, move workspace to eDP-1"
          "${pkgs.sway}/bin/swaymsg workspace number 4, move workspace to eDP-1"
        ];
      };

      helsinki = {
        outputs = [
          {
            criteria = "eDP-1";
            mode = "2256x1504";
            position = "0,850";
            scale = 1.5;
          }
          {
            criteria = "Lenovo Group Limited L32p-30 U5114TM2";
            mode = "3840x2160";
            position = "1504,0";
            scale = 1.5;
          }
        ];

        exec = [
          "${pkgs.sway}/bin/swaymsg workspace number 1, move workspace to '\"Lenovo Group Limited L32p-30 U5114TM2\"'"
          "${pkgs.sway}/bin/swaymsg workspace number 2, move workspace to '\"Lenovo Group Limited L32p-30 U5114TM2\"'"
          "${pkgs.sway}/bin/swaymsg workspace number 3, move workspace to eDP-1"
          "${pkgs.sway}/bin/swaymsg workspace number 4, move workspace to eDP-1"
        ];
      };

      bergen = {
        outputs = [
          {
            criteria = "eDP-1";
            mode = "2256x1504";
            position = "1920,100";
            scale = 1.5;
          }
          {
            criteria = "Hewlett Packard HP E242 CN472419MR";
            mode = "1920x1200";
            position = "0,0";
            scale = 1.0;
          }
        ];

        exec = [
          "${pkgs.sway}/bin/swaymsg workspace number 1, move workspace to '\"Hewlett Packard HP E242 CN472419MR\"'"
          "${pkgs.sway}/bin/swaymsg workspace number 2, move workspace to '\"Hewlett Packard HP E242 CN472419MR\"'"
          "${pkgs.sway}/bin/swaymsg workspace number 3, move workspace to eDP-1"
          "${pkgs.sway}/bin/swaymsg workspace number 4, move workspace to eDP-1"
        ];
      };
    };
  };
}
