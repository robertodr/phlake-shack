{ pkgs, ... }:
let
  lockCmd = "swaylock -k -l -i ${pkgs.pulse-demon}/share/blur-pulse-demon.png";
  resumeCmd = "swaymsg \"output * dpms on\"";
in
{
  services.swayidle = {
    enable = true;
    events = [
      # lock displays before going to sleep
      {
        event = "before-sleep";
        command = "${lockCmd}";
      }

      # turn displays back on when resuming
      {
        event = "after-resume";
        command = "${resumeCmd}";
      }
    ];
    timeouts = [
      # lock after 60 seconds idle
      {
        timeout = 60;
        command = "${lockCmd}";
      }

      # turn off displays after 120 seconds idle
      {
        timeout = 120;
        command = "swaymsg \"output * dpms off\"";
        resumeCommand = "${resumeCmd}";
      }
    ];
  };
}
