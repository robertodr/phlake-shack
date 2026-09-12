{
  config,
  lib,
  pkgs,
  ...
}:
{
  # nixos-hardware enables TLP...
  services.tlp.enable = lib.mkForce false;

  services.tuned = {
    enable = true;
    ppdSupport = true;
    package = pkgs.tuned.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./patches/systemd-sysctl-reapply.patch ];
      postPatch = (old.postPatch or "") + ''
        substituteInPlace tuned/plugins/plugin_sysctl.py \
          --replace-fail '@systemd_sysctl@' '${config.systemd.package}/lib/systemd/systemd-sysctl'

        # NetworkManager owns Wi-Fi power saving. The legacy iwpriv commands
        # used here are unsupported by mt7921e; retain the USB actions.
        substituteInPlace profiles/powersave/script.sh \
          --replace-fail '    enable_wifi_powersave' '    # Wi-Fi power saving is managed by NetworkManager.' \
          --replace-fail '    disable_wifi_powersave' '    # Wi-Fi power saving is managed by NetworkManager.'
      '';
    });
  };

  # virt-what uses `which` to find its bundled CPUID helper. Without it the
  # error misleadingly reports the helper itself as missing.
  systemd.services.tuned.path = [ pkgs.which ];

  # Nothing drops the machine into the power-saver tier when the charger comes
  # out: that is normally the desktop environment's job, and niri has no such
  # integration. tuned-ppd only picks the battery *variant* of whichever tier
  # it already holds, so unplugging gets balanced-battery, not powersave.
  #
  # This goes through the PPD D-Bus property rather than `tuned-adm profile`.
  # tuned-ppd owns the profile and re-applies its own tier over anything set
  # behind its back, so tuned-adm silently loses the race at boot; setting
  # ActiveProfile instead tells tuned-ppd what to want, and it picks the
  # matching tuned profile itself.
  systemd.services.tuned-power-source = {
    description = "Select the power profile matching the current power source";
    wantedBy = [ "multi-user.target" ];
    after = [ "tuned-ppd.service" ];
    wants = [ "tuned-ppd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "tuned-power-source" ''
        set -u
        busctl=${config.systemd.package}/bin/busctl
        dest="net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles"

        if [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)" = "1" ]; then
          want=balanced
        else
          want=power-saver
        fi

        # tuned-ppd applies its stored tier a moment after it takes its bus
        # name, so a single set issued during startup can still be overwritten.
        # Set, read back, retry.
        for _ in 1 2 3 4 5; do
          $busctl set-property $dest ActiveProfile s "$want" || true
          sleep 1
          if [ "$($busctl get-property $dest ActiveProfile)" = "s \"$want\"" ]; then
            echo "power profile: $want"
            exit 0
          fi
        done

        echo "failed to settle on power profile $want" >&2
        exit 1
      '';
    };
  };

  # Recheck the power source after wake even if no charger uevent arrives.
  # Queue a restart: this oneshot remains active after its first invocation.
  powerManagement.resumeCommands = ''
    ${config.systemd.package}/bin/systemctl --no-block restart tuned-power-source.service
  '';

  # The charger emits a change uevent on both plug and unplug.
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ACAD", RUN+="${config.systemd.package}/bin/systemctl --no-block restart tuned-power-source.service"
  '';
}
