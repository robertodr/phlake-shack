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
      # lock after 120 seconds idle
      {
        timeout = 120;
        command = "${lockCmd}";
      }

      # turn off displays after 240 seconds idle
      {
        timeout = 240;
        command = "if pgrep swaylock; then swaymsg \"output * dpms off\"; fi";
        resumeCommand = "if pgrep swaylock; ${resumeCmd}; fi";
      }
    ];
  };
}
