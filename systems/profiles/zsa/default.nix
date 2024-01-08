{pkgs, ...}: {
  hardware.keyboard.zsa.enable = true;

  environment = {
    # TODO review which packages should be here and which in user profiles
    systemPackages = [pkgs.wally-cli];
  };
}
