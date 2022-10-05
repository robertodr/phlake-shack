{ pkgs, ... }: {
  services.spotifyd = {
    enable = true;
    package = pkgs.spotifyd.override {
      withPulseAudio = true;
      withMpris = true;
    };
    settings = {
      global = {
        username = "bobert0";
        # FIXME use agenix
        password_cmd = "${pkgs.pass}/bin/pass spotify.com | ${pkgs.coreutils}/bin/head -n 1";
        # FIXME get machine name from configuration
        device_name = "pulsedemon";
        bitrate = 320;
        volume_normalisation = false;
        backend = "pulseaudio";
        use_mpris = true;
      };
    };
  };
}
