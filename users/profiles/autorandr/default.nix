{}:

let
  # lenovo screen, portrait
  lenovo_p = "00ffffffffffff0030aeed61000000000f1e0104a53c22783aee95a3544c99260f5054a54f00714fa9c08180d1c0a9cf9500b300d100565e00a0a0a029503020350055502100001a000000fd00324b1e5819010a202020202020000000fc004c454e20543237712d32300a20000000ff00564e4134464d52300a20202020019b02031cf14f90050403020716010611121513141f23091f0783010000023a801871382d40582c450055502100001e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f2";
  # lenovo screen, landscape
  lenovo_l = "00ffffffffffff0030aeed61000000000f1e0104a53c22783aee95a3544c99260f5054a54f00714fa9c08180d1c0a9cf9500b300d100565e00a0a0a029503020350055502100001a000000fd00324b1e5819010a202020202020000000fc004c454e20543237712d32300a20000000ff00564e4134464d50570a20202020017602031cf14f90050403020716010611121513141f23091f0783010000023a801871382d40582c450055502100001e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f2";
  # laptop screen
  edp_1 = "00ffffffffffff0009e5db0700000000011c0104a51f1178027d50a657529f27125054000000010101010101010101010101010101013a3880de703828403020360035ae1000001afb2c80de703828403020360035ae1000001a000000fe00424f452043510a202020202020000000fe004e4531343046484d2d4e36310a0043";
  # LG TV in Stockholm
  lgtv = "00ffffffffffff001e6d010001010101011b010380a05a780aee91a3544c99260f5054a108003140454061407140818001010101010108e80030f2705a80b0588a0040846300001e023a801871382d40582c450040846300001e000000fd003a791e883c000a202020202020000000fc004c472054560a202020202020200163020357f1565d101f0413051403021220212215015e5f6263643f402f0957071507505707013d06c06704036e030c001000b83c20008001020304e200cfe305c000e3060d01e50e60616566eb0146d000260a0975805b6c662150b051001b304070360040846300001e000000000000000000000000000000000000000000009b";
  # lenovo screen at home in Stockholm
  lenovo-q27q-10 = "00ffffffffffff0030aef46501010101201e0103803c22782a31d5a65453a0240a5054bfcf00d1c0d100b300a9c09500818081c08100e973006aa0a034504220680055502100001a565e00a0a0a029503020350055502100001a000000fd00304b0f6e1e000a202020202020000000fc00513237712d31300a202020202001fd020329f04b10050403021f1413121101230907078301000067030c001000383c681a00000101304b00023a801871382d40582c450055502100001e662156aa51001e30468f330055502100001eab22a0a050841a303020360055502100001a7c2e90a0601a1e403020360055502100001a000000000000000000000000000006";
  # samsung screen in Tromsø
  samsung = "00ffffffffffff004c2d730d39545a5a211e0103803c22782a5295a556549d250e5054bfef80714f81c0810081809500a9c0b3000101023a801871382d40582c450056502100001e000000fd00324b1e5111000a202020202020000000fc00533237463335380a2020202020000000ff0048345a4e3830313639340a202001ad020311b14690041f13120365030c001000011d00bc52d01e20b828554056502100001e8c0ad090204031200c4055005650210000188c0ad08a20e02d10103e96005650210000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e9";
  # asus screen at UiT
  asus = "00ffffffffffff0006b30027010101011a1f0104a53c22783bff15a6534a98260f5054bf4f00714f818081409500a940b300d100e1c0565e00a0a0a029503020350055502100001a000000fd002e4b70701e010a202020202020000000fc00504132373851560a2020202020000000ff004d364c4d51533137393238390a01f502031af14a900403021112131f05142309070783010000e2006a0e1f008051001e304080370055502100001c9774006ea0a034501720680855502100001a9e20009051201f304880360055502100001ccd4600a0a0381f4030203a0055502100001a00000000000000000000000000000000000000000000000000000000006a";
  #
  hp-l2245w = "00ffffffffffff0022f0fc260101010117120103802f1e78eeb130a5564a9a25115054a56bf0814081809500a900b30001010101010121399030621a274068b03600d9281100001c000000fd00324c185311000a202020202020000000fc004850204c32323435770a202020000000ff00435a4b383233303339300a20200099";
  # UiT
  hp-ZR2740w = "00ffffffffffff0022f05729000000001b170104b53c2278222e25a7554d9e260c505420000081c00101010101010101010101010101565e00a0a0a029503020220255502100001a1a1d008051d01c204080750055502100001e000000fc004850205a5232373430770a2020000000ff00434e54333237593032320a202000de00ffffffffffff0022f05729000000001b170104b53c2278222e25a7554d9e260c505420000081c00101010101010101010101010101565e00a0a0a029503020220255502100001a1a1d008051d01c204080750055502100001e000000fc004850205a5232373430770a2020000000ff00434e54333237593032320a202000de";
  # ATEM mini
  atem = "00ffffffffffff00230100000100000026100103804728960adaffa3584aa22917494b00000001010101010101010101010101010101023a801871382d40582c4500c48e2100001e023a80d072382d40582c4500c48e2100001e000000fc00424d442048444d490a20202020000000fd00323c1f4408000a20202020202001f702031f544985849493a0a1a29f90230904078301000068030c002000001e00011d007251d01e206e285500c48e2100001e011d00bc52d01e20b8285540c48e2100001e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e2";
  # ViewSonic (TCB)
  viewsonic = "00ffffffffffff005a63351901010101311b0103803c22782e2035a5544c9f260e5054bfef80e1c0d140d100d1c0b3009500818081c0565e00a0a0a029503020350055502100001a000000ff005634483137343930303133310a000000fd00184b0f781b000a202020202020000000fc005647323731392d324b0a20202001e2020333f15b010203040506070e0f901112131415161d1e1f222120565758595a23097f07830100006a030c0020003036200000023a801871382d40582c450055502100001e011d8018711c1620582c250055502100009e023a80d072382d40102c458055502100001e011d007251d01e206e28550055502100001e0000000011";
in
{
  programs.autorandr = {
    enable = true;
    profiles = {
      # docked at work
      "work" = {
        fingerprint = {
          DP-1-3 = "${lenovo_p}";
          DP-1-2 = "${lenovo_l}";
          eDP-1 = "${edp_1}";
        };
        config = {
          # portrait external screen
          DP-1-3 = {
            enable = true;
            crtc = 2;
            mode = "2560x1440";
            position = "4480x0";
            rate = "60.00";
            rotate = "right";
          };
          # landscape external screen
          DP-1-2 = {
            enable = true;
            crtc = 0;
            mode = "2560x1440";
            position = "1920x906";
            primary = true;
            rate = "60.00";
          };
          # laptop screen
          eDP-1 = {
            enable = true;
            crtc = 1;
            mode = "1920x1080";
            position = "0x1480";
            rate = "60.00";
          };
        };
      };

      # workshop configuration with ATEM mini
      "workshop" = {
        fingerprint = {
          DP-1-3 = "${lenovo_p}";
          DP-1-2 = "${lenovo_l}";
          DP-1-1 = "${atem}";
        };
        config = {
          # ATEM mini
          DP-1-1 = {
            enable = true;
            crtc = 1;
            mode = "1920x1080";
            position = "0x0";
            rate = "60.00";
            transform = [
              [ 1.333328 0.000000 0.000000 ]
              [ 0.000000 1.333328 0.000000 ]
              [ 0.000000 0.000000 1.000000 ]
            ];
          };
          # portrait external screen
          DP-1-3 = {
            enable = true;
            crtc = 2;
            mode = "2560x1440";
            position = "4480x0";
            rate = "60.00";
            rotate = "right";
          };
          # landscape external screen
          DP-1-2 = {
            enable = true;
            crtc = 0;
            mode = "2560x1440";
            #panning = "2560x1440+0+0";
            position = "0x0";
            rate = "60.00";
            primary = true;
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
            mode = "1920x1080";
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
            mode = "1920x1080";
            position = "2560x262";
            rate = "60.00";
          };
        };
      };

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
            mode = "1920x1080";
            position = "0x0";
            primary = true;
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
            mode = "1920x1080";
            position = "4096x1080";
            primary = true;
            rate = "60.00";
          };
        };
      };

      # Tromsø home
      "arbeidergata" = {
        # NOTE switch to HDMI-1 for the samsung screen when connected _without_ dock
        fingerprint = {
          DP-1-1 = "${samsung}";
          #HDMI-1 = "${samsung}";
          eDP-1 = "${edp_1}";
        };
        config = {
          DP-1-1 = {
            #HDMI-1 = {
            enable = true;
            crtc = 0;
            mode = "1920x1080";
            position = "1920x0";
            primary = true;
            rate = "60.00";
          };
          eDP-1 = {
            enable = true;
            crtc = 1;
            mode = "1920x1080";
            position = "0x0";
            rate = "60.00";
          };
        };
      };

      # Tromsø UiT
      "UiT" = {
        fingerprint = {
          DP-1-2 = "${hp-ZR2740w}";
          eDP-1 = "${edp_1}";
        };
        config = {
          DP-1-2 = {
            enable = true;
            crtc = 0;
            mode = "2560x1440";
            position = "1920x0";
            primary = true;
            rate = "60.00";
          };
          eDP-1 = {
            enable = true;
            crtc = 1;
            mode = "1920x1080";
            position = "0x598";
            rate = "60.00";
          };
        };
      };

      # Førde
      "forde" = {
        fingerprint = {
          HDMI-1 = "${hp-l2245w}";
          eDP-1 = "${edp_1}";
        };
        config = {
          HDMI-1 = {
            enable = true;
            crtc = 0;
            mode = "1680x1050";
            position = "1920x0";
            primary = true;
            rate = "60.00";
          };
          eDP-1 = {
            enable = true;
            crtc = 1;
            mode = "1920x1080";
            position = "0x720";
            rate = "60.00";
          };
        };
      };

      # TCB desk at KTH
      "tcb" = {
        fingerprint = {
          HDMI-1 = "${viewsonic}";
          eDP-1 = "${edp_1}";
        };
        config = {
          HDMI-1 = {
            enable = true;
            crtc = 0;
            mode = "2560x1440";
            position = "0x0";
            primary = true;
            rate = "60.00";
          };
          eDP-1 = {
            enable = true;
            crtc = 1;
            mode = "1920x1080";
            position = "2560x560";
            rate = "60.00";
          };
        };
      };
    };
  };
}
