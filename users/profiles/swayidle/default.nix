moduleArgs @ {pkgs, ...}: {
  services.swayidle = {
    enable = true;
    events = [
      # lock displays before going to sleep
      {
        event = "before-sleep";
        command = ''
          swaylock -k -l
        '';
      }

      # turn displays back on when resuming
      {
        event = "resume";
        command = ''
          swaymsg 'output * dpms on'
        '';
      }
    ];
    timeouts = [
      # lock after 60 seconds idle
      {
        timeout = 60;
        command = ''
          swaylock -k -l
        '';
      }

      # turn off displays after 120 seconds idle
      {
        timeout = 120;
        command = ''
          swaymsg 'output * dpms off'
        '';
      }
    ];
  };
}
