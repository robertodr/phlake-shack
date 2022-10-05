moduleArgs @ {pkgs, ...}: {
  services.swayidle = {
    enable = true;
    events = [
      {
        event = "before-sleep";
        command = "swaylock";
      }
      {
        event = "lock";
        command = "lock";
      }
    ];
  };

  home.packages = with pkgs; [
    swaylock
  ];
}
