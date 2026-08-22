{ pkgs, ... }:
{
  # Do nothing when the lid is closed while docked (external display connected)
  services.logind.settings.Login.HandleLidSwitchDocked = "ignore";

  # s2idle is the only sleep state this machine offers (/sys/power/mem_sleep
  # has no "deep"), and it keeps draining a few percent an hour. Hand over to
  # hibernation once the suspend has lasted half an hour, so an overnight
  # lid-close costs nothing. Needs boot.resumeDevice + resume_offset, which
  # kellanved already sets for its swapfile.
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "30min";
    # ...but only off the charger. On AC there is nothing to save, and
    # hibernating costs a full resume boot on a machine that was going to stay
    # plugged in anyway. This keeps the system suspended while AC is connected
    # and only starts the HibernateDelaySec countdown once it is unplugged, so
    # a lid-close at the desk resumes instantly.
    HibernateOnACPower = false;
  };

  # Stop charging at 80%. The Framework EC exposes the threshold through
  # cros-charge-control; the attribute only appears once that driver has
  # probed, hence the change action alongside add. Raise to 100 before a trip
  # where the extra fifth of the pack matters.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT?", ATTR{charge_control_end_threshold}=="?*", ATTR{charge_control_end_threshold}="80"
  '';

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
