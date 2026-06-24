{ ... }:
{
  services.pulseaudio.enable = false;

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = false;
    };
    pulse.enable = true;
    wireplumber.enable = true;
  };
}
