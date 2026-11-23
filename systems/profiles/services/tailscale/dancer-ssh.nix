_: {
  # First enrollment must use the same preferences. This is NOT a migration
  # mechanism for an already-enrolled daemon with old netfilter preferences.
  services.tailscale = {
    enable = true;
    interfaceName = "tailscale0";
    port = 41641;
    openFirewall = true;
    useRoutingFeatures = "none";
    authKeyFile = null;
    extraSetFlags = [
      "--netfilter-mode=off"
      "--ssh=false"
      "--accept-routes=false"
      "--advertise-exit-node=false"
      "--advertise-routes="
      "--exit-node="
    ];
  };

  # A non-routing endpoint; NixOS alone owns its packet-filter rules.
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 0;
    "net.ipv6.conf.all.forwarding" = 0;
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/tailscale";
      user = "root";
      group = "root";
      mode = "0700";
    }
  ];
}
