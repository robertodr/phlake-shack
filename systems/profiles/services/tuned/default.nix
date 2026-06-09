{ lib, ... }:
{
  # nixos-hardware enables TLP...
  services.tlp.enable = lib.mkForce false;

  services.tuned = {
    enable = true;
    ppdSupport = true;
  };
}
