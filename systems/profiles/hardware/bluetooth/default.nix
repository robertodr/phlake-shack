{ ... }:
{
  hardware = {
    bluetooth = {
      enable = true;
      # The radio otherwise idles at 100% utilisation in the powertop report.
      # The stack stays available; the adapter powers up on first use.
      powerOnBoot = false;
    };
  };
}
