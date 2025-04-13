{
  lib,
  pkgs,
  ...
}:
let
  tuigreet = lib.getExe pkgs.greetd.tuigreet;
  theme = "border=magenta;text=cyan;prompt=green;time=red;action=blue;button=yellow;container=black;input=redborder=magenta;text=cyan;prompt=green;time=red;action=blue;button=yellow;container=black;input=red";
in
{
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal"; # without this errors will spam on screen
    # without the following bootlogs will spam on screen
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${tuigreet} --debug --remember --remember-session --user-menu --theme '${theme}' --time --time-format '%_H:%M • %A • %B, %d %Y'";
        user = "greeter";
      };
    };
  };

  security.pam.services.greetd = {
    gnupg.enable = true;
  };
}
