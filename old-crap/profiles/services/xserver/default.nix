{
  config,
  lib,
  pkgs,
  ...
}: {
  services.xserver = {
    enable = true;

    # keyboard
    autoRepeatDelay = 200;
    autoRepeatInterval = 25;
    enableCtrlAltBackspace = true;
    exportConfiguration = true;
    layout = "it(us),no";
    xkbModel = "pc105";
    xkbOptions = "grp:alt_shift_toggle";

    # mouse and touchpad
    libinput = {
      enable = true;
      mouse = {
        naturalScrolling = true;
      };
      touchpad = {
        disableWhileTyping = true;
        naturalScrolling = true;
        scrollMethod = "twofinger";
        clickMethod = "clickfinger";
      };
    };

    serverLayoutSection = ''
      Option "StandbyTime" "0"
      Option "SuspendTime" "0"
      Option "OffTime"     "0"
    '';

    desktopManager = {
      xterm.enable = false;
    };

    displayManager = {
      defaultSession = "none+i3";
      lightdm = {
        enable = true;
        # FIXME figure how to get this one to work
        #background = ./background-image;
        greeters.gtk = {
          enable = true;
          iconTheme = {
            name = "ePapirus";
            package = pkgs.papirus-icon-theme;
          };
          indicators = [
            "~host"
            "~spacer"
            "~clock"
            "~spacer"
            "~session"
            "~power"
          ];
          clock-format = "%H:%M - %A, %B %d %Y";
        };
      };
    };

    windowManager.i3 = {
      enable = true;
      package = pkgs.i3-gaps;
      extraPackages = with pkgs; [
        betterlockscreen
      ];
    };
  };

  environment = {
    systemPackages = with pkgs; [
      xbindkeys # launch shell commands with your keyboard or your mouse under X Window
      xclip # tool to access the X clipboard from a console application
      xorg.lndir # create a shadow directory of symbolic links to another directory tree
      xsel # command-line program for getting and setting the contents of the X selection
    ];
  };
}
