{ lib, ... }:
{
  imports = [
    ./lan-only.nix
    ./dancer-firewall-lifecycle.nix
  ];

  networking.firewall = {
    # The pinned firewall recreates nixos-fw on start and calls stop commands
    # before reload. Insert AFTER lan-only's insertions, at position one, so
    # neither its SSH rejection nor generated global allowances bypass us.
    extraCommands = lib.mkAfter ''
      for tool in iptables ip6tables; do
        if ! "$tool" -w -nL dancer-ts-input >/dev/null 2>&1; then
          "$tool" -w -N dancer-ts-input
        fi
        "$tool" -w -F dancer-ts-input
        "$tool" -w -A dancer-ts-input -i lo -j RETURN
        "$tool" -w -A dancer-ts-input -i tailscale0 -p tcp --dport 22 -j nixos-fw-accept
        "$tool" -w -A dancer-ts-input -i tailscale0 -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
      done

      iptables -w -A dancer-ts-input -i tailscale0 -p icmp -j RETURN
      ip6tables -w -A dancer-ts-input -i tailscale0 -p ipv6-icmp -j RETURN

      for tool in iptables ip6tables; do
        "$tool" -w -A dancer-ts-input -i tailscale0 -j DROP
      done

      iptables -w -A dancer-ts-input -s 100.64.0.0/10 -j DROP
      ip6tables -w -A dancer-ts-input -s fd7a:115c:a1e0::/48 -j DROP

      for tool in iptables ip6tables; do
        "$tool" -w -A dancer-ts-input -j RETURN
        "$tool" -w -I nixos-fw 1 -j dancer-ts-input
      done
    '';

    # Only owned references/chains; never touch detached Tailscale or other
    # software's chains. Installation above must fail loudly on any error.
    extraStopCommands = lib.mkAfter ''
      for tool in iptables ip6tables; do
        "$tool" -w -D nixos-fw -j dancer-ts-input 2>/dev/null || true
        "$tool" -w -F dancer-ts-input 2>/dev/null || true
        "$tool" -w -X dancer-ts-input 2>/dev/null || true
      done
    '';
  };
}
