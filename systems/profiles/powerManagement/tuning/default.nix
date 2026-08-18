{ lib, pkgs, ... }:
let
  # Stage two of the mt7921e investigation. mt792x_pm_wake_work is the single
  # largest line in the powertop report: 1059 ms/s of work from only 1.3
  # events/s, i.e. the radio spends its time transitioning between deep sleep
  # and awake rather than resting in either. Stage one is PCIe runtime PM
  # (the udev rule below), which lets the function actually reach D3 between
  # wakes; measure that on its own first. If the churn survives it, flip this
  # to true: the driver's deep sleep path is flaky on mt7921/mt7922, and
  # switching it off while keeping 802.11 power save can lower the average
  # draw and remove the latency spikes at the same time.
  disableWifiDeepSleep = false;
in
{
  # Runtime power management tuning derived from powertop analysis.
  # tuned/PPD does not apply these device-level settings by default.

  # Audio codec runtime power saving (HDA controller).
  boot.extraModprobeConfig = ''
    options snd_hda_intel power_save=1 power_save_controller=Y
  '';

  boot.kernel.sysctl = {
    # Disable the NMI watchdog's per-CPU perf interrupt. Idle residency is
    # already ~95% in C3, so the saving is marginal; the real cost is that a
    # hard lockup will hang silently instead of panicking.
    "kernel.nmi_watchdog" = 0;
    # nmi_watchdog only covers the hard lockup detector; watchdog_timer_fn is
    # still in the report at 2.3 events/s. This switches off the soft lockup
    # detector too, which is the per-CPU timer actually doing the waking.
    "kernel.watchdog" = 0;
    # Batch dirty-page writeback into 15s intervals so the SSD and the LUKS
    # kcryptd workers idle longer. Widens the post-crash data loss window
    # from 5s to 15s.
    "vm.dirty_writeback_centisecs" = 1500;
  };

  services.udev.extraRules = ''
    # Enable PCIe runtime power management for all capable devices
    # (NVMe, WiFi, bridges) that powertop reports as untuned.
    ACTION=="add", SUBSYSTEM=="pci", TEST=="power/control", ATTR{power/control}="auto"

    # Enable USB autosuspend, excluding the Goodix fingerprint reader
    # (idVendor 27c6) to avoid authentication flakiness. DEVTYPE is matched
    # so this only hits usb_device nodes: usb_interface nodes have no
    # idVendor, and a missing attribute makes the != test succeed, which
    # would let the fingerprint reader's interfaces through the exclusion.
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", TEST=="power/control", ATTR{idVendor}!="27c6", ATTR{power/control}="auto"
  '';

  # WiFi (MediaTek MT7922/mt7921e) power saving. The radio is a top-5 power
  # consumer in the powertop report, so leave the driver's power save on.
  # Set this to false if the resulting latency spikes become a problem.
  networking.networkmanager.wifi.powersave = true;

  # The knob lives in debugfs, which udev cannot write to, so it needs a unit.
  # It has to run after the mt7921e module has created the phy, and has to be
  # reapplied on resume because debugfs state does not survive the reset.
  systemd.services.mt76-no-deep-sleep = lib.mkIf disableWifiDeepSleep {
    description = "Disable mt76 deep sleep (keeps 802.11 power save on)";
    wantedBy = [
      "multi-user.target"
      "post-resume.target"
    ];
    after = [ "post-resume.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "mt76-no-deep-sleep" ''
        knob=/sys/kernel/debug/ieee80211/phy0/mt76/deep_sleep
        # The phy shows up asynchronously after the module loads.
        for _ in $(seq 50); do
          [ -e "$knob" ] && break
          sleep 0.1
        done
        [ -e "$knob" ] || exit 0
        echo 0 > "$knob"
      '';
    };
  };

  # Use periodic TRIM instead of continuous discard to reduce background work.
  # btrfs turns on discard=async by default for SSDs (visible as
  # btrfs_discard_workfn in the powertop report), so the async discard worker
  # has to be switched off explicitly for fstrim to actually replace it.
  # These merge with the mount options that disko declares in disk-config.nix,
  # and are kept here rather than there so that dropping this profile restores
  # discard=async instead of leaving the filesystem with no TRIM at all.
  fileSystems = {
    "/".options = [ "nodiscard" ];
    "/nix".options = [ "nodiscard" ];
    "/home".options = [ "nodiscard" ];
    "/persist".options = [ "nodiscard" ];
    "/.swapvol".options = [ "nodiscard" ];
  };

  services.fstrim.enable = true;
}
