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

      # if playing music, pause it
      {
        event = "before-sleep";
        command = "${pkgs.playerctl}/bin/playerctl -a pause";
      }

      # turn displays back on when resuming
      {
        event = "after-resume";
        command = "${resumeCmd}";
      }
    ];
    timeouts = [
      # turn off displays after 300 seconds idle
      {
        timeout = 300;
        command = "swaymsg \"output * dpms off\"";
        #command = "if pgrep swaylock; then swaymsg \"output * dpms off\"; fi";
        #resumeCommand = "if pgrep swaylock; ${resumeCmd}; fi";
        resumeCommand = "${resumeCmd}";
      }

      # lock after 350 seconds idle
      {
        timeout = 350;
        command = "${lockCmd}";
      }
    ];
  };
}
