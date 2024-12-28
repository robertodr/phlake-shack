{
  lib,
  pkgs,
  ...
}: {
  name = "uio";
  exec = [
    "${lib.getExe pkgs.libnotify} shikane \"Profile $SHIKANE_PROFILE_NAME has been applied\""
  ];
  output = [
    {
      search = "eDP-1";
      enable = true;
      mode = "2256x1504@60Hz";
      position = "344,1440";
      scale = 1.6;
    }
    {
      search = "%Dell Inc. DELL U2720Q HR5GZ13";
      enable = true;
      mode = "3840x2160@60Hz";
      position = "0,0";
      scale = 1.5;
      adaptive_sync = true;
    }
  ];
}
