{ pkgs, ... }:
{
  powerManagement = {
    enable = true;
    powertop.enable = false;
    # use in place of hypridle's before_sleep_cmd, since systemd does not wait
    # for it to complete
    powerDownCommands = ''
      # Lock all sessions
      loginctl lock-sessions

      # Wait for lockscreen(s) to be up
      sleep 1
    '';
  };

  environment = {
    systemPackages = [ pkgs.powertop ];
  };
}
