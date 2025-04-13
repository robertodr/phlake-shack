{ ... }:
{
  systemd = {
    tmpfiles.rules = [ "d /tmp 1777 root root 10d" ];
  };
}
