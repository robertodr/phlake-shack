{ ... }:
{
  # systemd-oomd is enabled by default, but all three of its slice options
  # default to false, so out of the box it runs without monitoring anything.
  # These are what make it actually act; without them, dropping earlyoom would
  # leave the machine with no userspace OOM handling at all.
  systemd.oomd = {
    enable = true;
    # Kill the heaviest cgroup under -.slice once swap is nearly exhausted.
    enableRootSlice = true;
    # Act on sustained memory pressure inside the user session, which is where
    # a runaway browser or build actually lives.
    enableUserSlices = true;
    # Deliberately left off: pressure-killing inside system.slice takes out
    # daemons rather than the process responsible for the pressure.
    enableSystemSlice = false;
  };
}
