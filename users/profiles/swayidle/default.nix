{pkgs, ...}: let
  lockCmd = "swaylock -k -l -i ${pkgs.pulse-demon}/share/blur-pulse-demon.png";
  resumeCmd = "swaymsg \"output * dpms on\"";
in {
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
      # turn off displays after 120 seconds idle
      {
        timeout = 120;
        command = "swaymsg \"output * dpms off\"";
        #command = "if pgrep swaylock; then swaymsg \"output * dpms off\"; fi";
        #resumeCommand = "if pgrep swaylock; ${resumeCmd}; fi";
        resumeCommand = "${resumeCmd}";
      }

      # lock after 150 seconds idle
      {
        timeout = 150;
        command = "${lockCmd}";
      }
    ];
  };
}
