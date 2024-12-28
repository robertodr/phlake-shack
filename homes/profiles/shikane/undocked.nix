{lib, pkgs, ...}:
{
        name = "undocked";
        exec = [
          "${lib.getExe pkgs.libnotify} shikane \"Profile $SHIKANE_PROFILE_NAME has been applied\""
        ];
        output = [
          {
            enable = true;
            search = "eDP-1";
            position = "0,0";
            mode = "2256x1504@60Hz";
            scale = 1.175;
          }
        ];
}
