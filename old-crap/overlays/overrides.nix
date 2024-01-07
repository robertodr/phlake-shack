channels: final: prev: {
  __dontExport = true; # overrides clutter up actual creations

  inherit
    (channels.latest)
    alejandra
    cachix
    dhall
    nix-index
    nixpkgs-fmt
    onlyoffice-bin
    rage
    starship
    thunderbird
    treefmt
    zoom-us
    ;
}
