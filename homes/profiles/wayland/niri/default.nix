{
  pkgs,
  lib,
  ...
}:
let
  take-screenshot = pkgs.writeShellScriptBin "take-screenshot.sh" ''
    ${lib.getExe pkgs.wayfreeze} & PID=$!; sleep .1; ${lib.getExe pkgs.grim} -t ppm -g "$(${lib.getExe pkgs.slurp} -o -d -F monospace)" - | wl-copy; kill $PID;

    wl-paste | satty --filename - --copy-command="wl-copy" --annotation-size-factor 0.5 --output-filename="$XDG_SCREENSHOTS_DIR/Screenshot_%Y-%m-%d_%H:%M:%S.png" --actions-on-enter="save-to-clipboard,exit" --brush-smooth-history-size 2 --disable-notifications
  '';
  configKdl = builtins.readFile ./config.kdl;
  # substitute the placeholder with the actual store path
  configKdlPatched =
    builtins.replaceStrings [ "TAKE-SCREENSHOT" ] [ "${lib.getExe take-screenshot}" ]
      configKdl;
in
{
  home = {
    packages = [
      pkgs.udiskie
      pkgs.waypipe
      pkgs.wl-clipboard
    ];
  };

  xdg.configFile."niri/config.kdl".text = configKdlPatched;
}
