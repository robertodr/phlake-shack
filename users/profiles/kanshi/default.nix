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

      tromso = import ./tromso.nix {inherit pkgs;};

      helsinki = import ./helsinki.nix {inherit pkgs;};

      bergen = import ./bergen.nix {inherit pkgs;};
    };
  };
}
