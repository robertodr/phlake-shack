{pkgs, ...}: {
  services.greetd = {
    enable = true;
    package = pkgs.greetd.gtkgreet;
    settings = {
      default_session.command = "sway --config /etc/greetd/sway-config";
    };
  };

  security.pam.services.greetd.enableGnomeKeyring = true;

  environment.etc = {
    "greetd/environments".text = ''
      sway
      fish
    '';

    "greetd/sway-config".text = ''
      # `-l` activates layer-shell mode. Notice that `swaymsg exit` will run after gtkgreet.
      exec "${pkgs.greetd.gtkgreet}/bin/gtkgreet -l; swaymsg exit"

      input type:keyboard xkb_layout it(us)

      bindsym Mod4+shift+e exec swaynag \
        -t warning \
        -m 'What do you want to do?' \
        -b 'Poweroff' 'systemctl poweroff' \
        -b 'Reboot' 'systemctl reboot'

      include /etc/sway/config.d/*
    '';

    "greetd/gtkgreet.css".text = ''
      window {
        background-image: url("file://${pkgs.pulse-demon}/share/flop-blur-pulse-demon.png");
        background-size: cover;
        background-position: center;
      }
    '';
  };
}
