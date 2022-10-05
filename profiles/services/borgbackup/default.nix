{
  config,
  lib,
  pkgs,
  ...
}: {
  services = {
    borgbackup.jobs = {
      roberto = rec {
        user = "roberto";
        paths = [
          "/home/${user}/Documents"
          "/home/${user}/Downloads"
          "/home/${user}/Pictures"
        ];
        #exclude = [ "/nix" "'**/.cache'" ];
        doInit = false;
        repo = "yc4l17r5@yc4l17r5.repo.borgbase.com:repo";
        encryption = {
          mode = "repokey-blake2";
          passCommand = "${pkgs.pass}/bin/pass show yc4l17r5.repo.borgbase.com";
        };
        compression = "auto,lzma";
        startAt = "Thu *-*-* 14:00:00";
      };
    };
  };
}
