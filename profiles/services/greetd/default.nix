{pkgs, ...}: let
  gtkgreetStyle = pkgs.writeText "greetd-gtkgreet.css" ''
    window {
      background-image: url("file://${pkgs.pulse-demon}/share/flop-blur-pulse-demon.png");
      background-size: cover;
      background-position: center;
      font-weight: bold;
    }
  '';

  greetdSwayConfig = pkgs.writeText "greetd-sway-config" ''
    # needed?
    # exec "dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP"
    input type:keyboard xkb_layout it(us)

    bindsym Mod4+shift+e exec ${pkgs.sway}/bin/swaynag \
      -t warning \
      -m 'What do you want to do?' \
      -b 'Poweroff' 'systemctl poweroff' \
      -b 'Reboot' 'systemctl reboot'

    include /etc/sway/config.d/*

    # `-l` activates layer-shell mode. Notice that `swaymsg exit` will run after gtkgreet.
    exec "${pkgs.greetd.gtkgreet}/bin/gtkgreet -l -s ${gtkgreetStyle}; ${pkgs.sway}/bin/swaymsg exit"
  '';
in {
  services.greetd = {
    enable = true;
    package = pkgs.greetd.gtkgreet;
    settings = {
      default_session.command = "${pkgs.sway}/bin/sway --config ${greetdSwayConfig}";
    };
  };

  security.pam.services.greetd = {
    enableGnomeKeyring = true;
    gnupg.enable = true;
  };

  environment.etc = {
    "greetd/environments".text = ''
      sway
      fish
    '';
  };
}
