{ pkgs, ... }:
{
  services.dbus = {
    enable = true;
    implementation = "broker";
    packages = with pkgs; [
      dconf
    ];
  };
}
