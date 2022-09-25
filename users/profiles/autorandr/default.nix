{ pkgs, ... }:

let
  # laptop screen
  edp_1 = "00ffffffffffff0030e48b0500000000001a0104a51f1178e25715a150469d290f505400000001010101010101010101010101010101695e00a0a0a029503020a50035ae1000001a000000000000000000000000000000000000000000fe004c4720446973706c61790a2020000000fe004c503134305148322d5350423100b8";
  # LG TV in Stockholm
  lgtv = "00ffffffffffff001e6d010001010101011b010380a05a780aee91a3544c99260f5054a108003140454061407140818001010101010108e80030f2705a80b0588a0040846300001e023a801871382d40582c450040846300001e000000fd003a791e883c000a202020202020000000fc004c472054560a202020202020200163020357f1565d101f0413051403021220212215015e5f6263643f402f0957071507505707013d06c06704036e030c001000b83c20008001020304e200cfe305c000e3060d01e50e60616566eb0146d000260a0975805b6c662150b051001b304070360040846300001e000000000000000000000000000000000000000000009b";
  # lenovo screen at home in Stockholm
  lenovo-q27q-10 = "00ffffffffffff0030aef46501010101201e0103803c22782a31d5a65453a0240a5054bfcf00d1c0d100b300a9c09500818081c08100e973006aa0a034504220680055502100001a565e00a0a0a029503020350055502100001a000000fd00304b0f6e1e000a202020202020000000fc00513237712d31300a202020202001fd020329f04b10050403021f1413121101230907078301000067030c001000383c681a00000101304b00023a801871382d40582c450055502100001e662156aa51001e30468f330055502100001eab22a0a050841a303020360055502100001a7c2e90a0601a1e403020360055502100001a000000000000000000000000000006";
in
{
  programs.autorandr = {
    enable = true;

    profiles = {
      # undocked, usually when on the move
      "travel" = {
        fingerprint = {
          eDP-1 = "${edp_1}";
        };
        # laptop screen
        config = {
          eDP-1 = {
            enable = true;
            crtc = 0;
            mode = "2560x1440";
            position = "0x0";
            primary = true;
            rate = "60.00";
          };
        };
      };

      # docked at home in Stockholm
      "homedock" = {
        fingerprint = {
          DP-1-2 = "${lenovo-q27q-10}";
          eDP-1 = "${edp_1}";
        };
        config = {
          # external screen
          DP-1-2 = {
            enable = true;
            crtc = 0;
            mode = "2560x1440";
            position = "0x0";
            rate = "74.60";
            primary = true;
          };
          # laptop screen
          eDP-1 = {
            enable = true;
            crtc = 1;
            mode = "2560x1440";
            position = "2560x262";
            rate = "60.00";
          };
        };
      };

      # home in Stockholm, no dock
      "home" = {
        fingerprint = {
          HDMI-1 = "${lenovo-q27q-10}";
          eDP-1 = "${edp_1}";
        };
        config = {
          # external screen
          HDMI-1 = {
            enable = true;
            crtc = 0;
            mode = "2560x1440";
            position = "0x0";
            rate = "74.60";
            primary = true;
          };
          # laptop screen
          eDP-1 = {
            enable = true;
            crtc = 1;
            mode = "2560x1440";
            position = "2560x262";
            rate = "60.00";
          };
        };
      };

      # connected to TV
      "tv" = {
        fingerprint = {
          HDMI-1 = "${lgtv}";
          eDP-1 = "${edp_1}";
        };
        config = {
          HDMI-1 = {
            enable = true;
            crtc = 1;
            mode = "4096x2160";
            position = "0x0";
            rate = "30.00";
          };
          eDP-1 = {
            enable = true;
            crtc = 0;
            mode = "2560x1440";
            position = "4096x1080";
            primary = true;
            rate = "60.00";
          };
        };
      };
    };

    hooks = {
      postswitch = {
        "notify-i3" = "${pkgs.i3-gaps}/bin/i3-msg restart";
        "change-dpi" = ''
          # FIXME do I need this part?
          #case "$AUTORANDR_CURRENT_PROFILE" in
          #  default)
          #    DPI=220
          #    ;;
          #  travel)
          #    DPI=220
          #    ;;
          #  *)
          #    echo "Unknown profle: $AUTORANDR_CURRENT_PROFILE"
          #    exit 1
          #esac

          echo "Xft.dpi: 192" | ${pkgs.xorg.xrdb}/bin/xrdb -merge
        '';
      };
    };
  };
}
