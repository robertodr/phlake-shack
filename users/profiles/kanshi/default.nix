{pkgs, ...}: {
  home.packages = [
    pkgs.wdisplays
  ];

  services.kanshi = {
    enable = true;

    profiles = {
      undocked = import ./undocked.nix;

      docked = import ./docked.nix {inherit pkgs;};

      kth = import ./kth.nix {inherit pkgs;};

      uit = import ./uit.nix {inherit pkgs;};

      uio = import ./uio.nix {inherit pkgs;};

      algo-hq = import ./algo-hq.nix {inherit pkgs;};

      bergen = import ./bergen.nix {inherit pkgs;};
    };
  };
}
