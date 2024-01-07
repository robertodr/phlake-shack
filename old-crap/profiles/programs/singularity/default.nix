{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    squashfsTools # tool for creating and unpacking squashfs filesystems
  ];

  programs = {
    singularity.enable = true;
  };
}
