{
  mountdir,
  pkgs,
  ...
}: let
  folder = "${mountdir}/paperpile";
in {
  # before this can succeed, you have to configure rclone to work with Google Drive:
  # https://rclone.org/drive/
  Unit = {
    Description = "Mount Google Drive Paperpile directory";
  };
  Install.WantedBy = ["default.target"];
  Service = {
    ExecStartPre = "/run/current-system/sw/bin/mkdir -p ${folder}";
    # options used:
    # --cache-db-purge             Clear all the cached data for this remote on start.
    # --fast-list                  Use recursive list if available. Uses more memory but fewer transactions.
    # --poll-interval              Time to wait between polling for changes.
    # --dir-cache-time             Time to cache directory entries for.
    # --vfs-cache-max-age          Max age of objects in the cache.
    # --vfs-read-chunk-size        Read the source objects in chunks.
    # --vfs-read-chunk-size-limit  Double the chunk size after each chunk read, until the limit is reached.
    # --buffer-size                In memory buffer size when reading files for each --transfer.
    ExecStart = ''
      ${pkgs.rclone}/bin/rclone mount gdrive:"Paperpile/all" ${folder} \
                                      --cache-db-purge \
                                      --fast-list \
                                      --poll-interval 10m \
                                      --dir-cache-time 48h \
                                      --vfs-cache-max-age 48h \
                                      --vfs-read-chunk-size 32M \
                                      --vfs-read-chunk-size-limit 512M \
                                      --buffer-size 512M
    '';
    ExecStop = "${pkgs.fuse}/bin/fusermount -u ${folder}";
    Type = "notify";
    Restart = "always";
    RestartSec = "10s";
    Environment = ["PATH=/run/wrappers/bin:$PATH"];
  };
}
