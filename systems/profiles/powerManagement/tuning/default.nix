{ ... }:
{
  # Runtime power management tuning derived from powertop analysis.
  # tuned/PPD does not apply these device-level settings by default.

  # Audio codec runtime power saving (HDA controller).
  boot.extraModprobeConfig = ''
    options snd_hda_intel power_save=1 power_save_controller=Y
  '';

  boot.kernel.sysctl = {
    # Disable NMI watchdog to avoid periodic per-CPU wakeups.
    "kernel.nmi_watchdog" = 0;
    # Batch dirty-page writeback to reduce disk wakeups.
    "vm.dirty_writeback_centisecs" = 1500;
  };

  services.udev.extraRules = ''
    # Enable PCIe runtime power management for all capable devices
    # (NVMe, WiFi, bridges) that powertop reports as untuned.
    ACTION=="add", SUBSYSTEM=="pci", TEST=="power/control", ATTR{power/control}="auto"

    # Enable USB autosuspend, excluding the Goodix fingerprint reader
    # (idVendor 27c6) to avoid authentication flakiness.
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{idVendor}!="27c6", ATTR{power/control}="auto"
  '';

  # WiFi (MediaTek MT7921) power saving; addresses periodic radio wakeups.
  networking.networkmanager.wifi.powersave = true;

  # Use periodic TRIM instead of continuous discard to reduce background work.
  services.fstrim.enable = true;
}
