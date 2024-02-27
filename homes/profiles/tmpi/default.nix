{
  config,
  pkgs,
  ...
}: let
  inherit (config.xdg) configHome;
  inherit (config.lib.dag) entryAfter;

  localBin = "$HOME/.local/bin";
in {
  home.sessionPath = ["${localBin}"];

  home.activation.installTmpi = let
    curl = "$DRY_RUN_CMD ${pkgs.curl}/bin/curl";
  in
    entryAfter ["writeBoundary"] ''
      if [[ ! -f "${localBin}/tmpi" ]]; then
        mkdir -p ${localBin}
        ${curl} https://raw.githubusercontent.com/Azrael3000/tmpi/master/tmpi -o ${localBin}/tmpi
        chmod u+x ${localBin}/tmpi
      fi
    '';

  programs.tmux = {enable = true;};
}
