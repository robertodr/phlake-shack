_: {
  # User-owned client, not tag:dancer. Retain the client's normal netfilter
  # integration and existing inbound firewall; do not import the server guard.
  services.tailscale = {
    enable = true;
    openFirewall = false;
    authKeyFile = null;
    extraSetFlags = [ "--ssh=false" ];
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
