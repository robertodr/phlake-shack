final: prev: {
  # keep sources this first
  sources = prev.callPackage (import ./_sources/generated.nix) { };

  # then, call packages with `final.callPackage`
  pulse-demon = final.callPackage ./pulse-demon { };

  #openconnect-sso = final.libsForQt5.callPackage ./openconnect-sso {
  #  inherit (sources);
  #};
}
