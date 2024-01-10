{...}: {
  services.tlp = {
    enable = true;
    settings = {
      # these options are from the official guide for Ubuntu
      # https://knowledgebase.frame.work/en_us/optimizing-ubuntu-battery-life-Sye_48Lg3
      # they seem to _significantly_ worsen fan noise
      #INTEL_GPU_MIN_FREQ_ON_AC = 100;
      #INTEL_GPU_MIN_FREQ_ON_BAT = 100;
      #INTEL_GPU_MAX_FREQ_ON_AC = 1450;
      #INTEL_GPU_MAX_FREQ_ON_BAT = 800;
      #INTEL_GPU_BOOST_FREQ_ON_AC = 1450;
      #INTEL_GPU_BOOST_FREQ_ON_BAT = 1000;
      #WIFI_PWR_ON_AC = "off";
      #WIFI_PWR_ON_BAT = "off";
      #WOL_DISABLE = "Y";
      #PCIE_ASPM_ON_AC = "default";
      #PCIE_ASPM_ON_BAT = "powersupersave";
      #RUNTIME_PM_ON_AC = "on";
      #RUNTIME_PM_ON_BAT = "auto";
      #CPU_SCALING_GOVERNOR_ON_AC = "performance";
      #CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      #CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      #CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      #CPU_MIN_PERF_ON_AC = 0;
      #CPU_MAX_PERF_ON_AC = 100;
      #CPU_MIN_PERF_ON_BAT = 0;
      #CPU_MAX_PERF_ON_BAT = 30;
      #CPU_BOOST_ON_AC = 1;
      #CPU_BOOST_ON_BAT = 0;
      #CPU_HWP_DYN_BOOST_ON_AC = 1;
      #CPU_HWP_DYN_BOOST_ON_BAT = 0;
      #SCHED_POWERSAVE_ON_AC = 0;
      #SCHED_POWERSAVE_ON_BAT = 1;
      #NMI_WATCHDOG = 0;
      #PLATFORM_PROFILE_ON_AC = "performance";
      #PLATFORM_PROFILE_ON_BAT = "low-power";
      #USB_AUTOSUSPEND = 1;
      #USB_EXCLUDE_AUDIO = 1;
      #USB_EXCLUDE_BTUSB = 0;
      #USB_EXCLUDE_PHONE = 0;
      #USB_EXCLUDE_PRINTER = 1;
      #USB_EXCLUDE_WWAN = 0;
      #USB_AUTOSUSPEND_DISABLE_ON_SHUTDOWN = 0;
      ## Lenovo ThinkPad Thunderbolt 3 Dock MCU
      #USB_ALLOWLIST = "17ef:3066";

      CPU_BOOST_ON_BAT = 0;
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BATTERY = "powersave";
      PCIE_ASPM_ON_BAT = "powersupersave";
      RUNTIME_PM_ON_BAT = "auto";
      START_CHARGE_THRESH_BAT0 = 90;
      STOP_CHARGE_THRESH_BAT0 = 97;
    };
  };
}
