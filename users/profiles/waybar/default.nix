{ pkgs, ... }: {
  programs.waybar = {
    enable = true;

    systemd.enable = true;

    package = pkgs.waybar.override {
      withMediaPlayer = true;
    };

    # TODO add fancy configuration :)
  };
}
