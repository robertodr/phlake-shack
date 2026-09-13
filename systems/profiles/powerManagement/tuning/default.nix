{
  config,
  lib,
  pkgs,
  ...
}:
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
    #
    # This is the battery setting; usb-autosuspend-power-source.service flips
    # it back to "on" while the charger is in. The rule still sets "auto"
    # unconditionally so a device plugged in on battery is tuned immediately
    # rather than waiting for the service, and it nudges the service from here
    # so a device plugged in on AC does not keep the autosuspend it just got.
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", TEST=="power/control", ATTR{idVendor}!="27c6", ATTR{power/control}="auto", RUN+="${config.systemd.package}/bin/systemctl --no-block restart usb-autosuspend-power-source.service"

    # The charger emits a change uevent on both plug and unplug.
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ACAD", RUN+="${config.systemd.package}/bin/systemctl --no-block restart usb-autosuspend-power-source.service bluetooth-power-source.service"
  '';

  # NixOS runs resumeCommands when sleep-actions.service stops after wake.
  # Explicitly restart these RemainAfterExit services so they run every time;
  # starting an already-active service would do nothing. Queue the jobs without
  # blocking the sleep transaction on services with normal target ordering.
  powerManagement.resumeCommands = ''
    ${config.systemd.package}/bin/systemctl --no-block restart usb-autosuspend-power-source.service bluetooth-power-source.service
    ${lib.optionalString disableWifiDeepSleep ''
      ${config.systemd.package}/bin/systemctl --no-block restart mt76-no-deep-sleep.service
    ''}
  '';

  # Autosuspend costs latency on wake and upsets some peripherals (hubs,
  # docks, audio interfaces), and the power it saves only matters off the
  # charger. So keep it on battery and switch it off on AC, following the
  # power-source handling in the tuned profile.
  systemd.services.usb-autosuspend-power-source = {
    description = "Set USB autosuspend to match the current power source";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "usb-autosuspend-power-source" ''
        set -u

        # Default to treating the machine as plugged in: that is the setting
        # that cannot make a device misbehave.
        if [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)" = "1" ]; then
          want=on
        else
          want=auto
        fi

        for dev in /sys/bus/usb/devices/*; do
          # Only usb_device nodes carry idVendor, so this skips usb_interface
          # nodes, and it leaves the Goodix fingerprint reader alone exactly
          # as the udev rule above does.
          [ -r "$dev/idVendor" ] || continue
          [ "$(cat "$dev/idVendor")" = "27c6" ] && continue
          [ -w "$dev/power/control" ] || continue
          echo "$want" > "$dev/power/control" || true
        done

        echo "usb autosuspend: $want"
      '';
    };
  };

  # Disconnect Bluetooth before every suspend/hibernate, not after waking.
  # StopWhenUnneeded resets this oneshot after sleep.target stops, so the
  # next sleep runs it again. Bound failures so BlueZ cannot block sleep.
  systemd.services.bluetooth-sleep = {
    description = "Power off Bluetooth before sleep";
    wantedBy = [ "sleep.target" ];
    before = [ "sleep.target" ];
    after = [
      "bluetooth.service"
      "bluetooth-power-source.service"
    ];
    unitConfig.StopWhenUnneeded = true;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if ! ${config.systemd.package}/bin/systemctl is-active --quiet bluetooth.service; then
        echo "bluetooth: daemon inactive, nothing to power off"
        exit 0
      fi

      if ${pkgs.coreutils}/bin/timeout 5s ${config.hardware.bluetooth.package}/bin/bluetoothctl power off; then
        echo "bluetooth: powered off before sleep"
      else
        echo "bluetooth: could not power off before sleep; continuing" >&2
      fi
    '';
  };

  # Bluetooth starts off at boot (powerOnBoot = false), and bluetooth-sleep
  # turns it off before sleeping. Enable it on AC; on battery leave it off
  # after wake until the user enables it. Preserve manual changes on battery
  # rather than interrupting connections whenever a charger uevent arrives.
  systemd.services.bluetooth-power-source = {
    description = "Power the Bluetooth adapter to match the current power source";
    wantedBy = [ "multi-user.target" ];
    after = [ "bluetooth.service" ];
    wants = [ "bluetooth.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "bluetooth-power-source" ''
        set -u
        bluetoothctl=${config.hardware.bluetooth.package}/bin/bluetoothctl

        # Ignore charger events during sleep (including the intermediate
        # suspend-to-hibernate wake). The resume hook retries after sleep.
        if ${config.systemd.package}/bin/systemctl is-active --quiet sleep.target; then
          echo "bluetooth: sleep in progress, leaving adapter off"
          exit 0
        fi

        # The controller registers with bluetoothd asynchronously, and on
        # resume it is re-added after the daemon is already up.
        for _ in $(seq 50); do
          [ -n "$($bluetoothctl list)" ] && break
          sleep 0.1
        done
        if [ -z "$($bluetoothctl list)" ]; then
          echo "bluetooth: no controller, nothing to do"
          exit 0
        fi

        if [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)" = "1" ]; then
          $bluetoothctl power on
          echo "bluetooth: powered on (AC)"
          exit 0
        fi

        echo "bluetooth: preserving adapter power state (battery)"
      '';
    };
  };

  # WiFi (MediaTek MT7922/mt7921e) power saving. The radio is a top-5 power
  # consumer in the powertop report, so leave the driver's power save on.
  # Set this to false if the resulting latency spikes become a problem.
  networking.networkmanager.wifi.powersave = true;

  # The knob lives in debugfs, which udev cannot write to, so it needs a unit.
  # It has to run after the mt7921e module has created the phy, and has to be
  # reapplied on resume because debugfs state does not survive the reset.
  systemd.services.mt76-no-deep-sleep = lib.mkIf disableWifiDeepSleep {
    description = "Disable mt76 deep sleep (keeps 802.11 power save on)";
    wantedBy = [ "multi-user.target" ];
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
