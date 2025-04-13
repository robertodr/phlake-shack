{ ... }:
{
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          # https://wiki.nixos.org/wiki/Bluetooth#Enabling_A2DP_Sink
          Enable = "Source,Sink,Media,Socket";
          # https://wiki.nixos.org/wiki/Bluetooth#Showing_battery_charge_of_bluetooth_devices
          Experimental = true;
        };
      };
    };
  };
}
