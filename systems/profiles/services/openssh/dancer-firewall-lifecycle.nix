{
  config,
  lib,
  pkgs,
  ...
}:
let
  fw = config.networking.firewall;
  # Canonicalized by the installed iptables tools in an unhooked staging chain.
  # This is verification data for the pinned backend, not a replacement firewall.
  state = "-m conntrack --ctstate ESTABLISHED,RELATED";
  icmp =
    family:
    if family == 4 then
      lib.optional fw.allowPing (
        "-p icmp --icmp-type echo-request "
        + lib.optionalString (fw.pingLimit != null) "-m limit ${fw.pingLimit} "
        + "-j ACCEPT"
      )
    else
      [
        "-p ipv6-icmp --icmpv6-type redirect -j DROP"
        "-p ipv6-icmp --icmpv6-type 139 -j DROP"
        "-p ipv6-icmp -j ACCEPT"
      ];
  spoof = family: if family == 4 then "100.64.0.0/10" else "fd7a:115c:a1e0::/48";
  hold =
    family:
    [
      "-i lo -j RETURN"
      "-i tailscale0 -p tcp --dport 22 -j ACCEPT"
      "-i tailscale0 ${state} -j ACCEPT"
    ]
    ++ map (r: "-i tailscale0 ${r}") (icmp family)
    ++ [
      "-i tailscale0 -j DROP"
      "-s ${spoof family} -j DROP"
    ]
    ++ lib.optional (family == 4) "-p tcp --dport 22 -s 192.168.68.0/22 -j ACCEPT"
    ++ [
      "-p tcp --dport 22 -j REJECT --reject-with tcp-reset"
      "${state} -j ACCEPT"
      "-p udp --dport 41641 -j ACCEPT"
    ]
    ++ icmp family
    ++ [ "-j DROP" ];
  guard = family: [
    "-i lo -j RETURN"
    "-i tailscale0 -p tcp --dport 22 -j nixos-fw-accept"
    "-i tailscale0 ${state} -j RETURN"
    "-i tailscale0 -p ${if family == 4 then "icmp" else "ipv6-icmp"} -j RETURN"
    "-i tailscale0 -j DROP"
    "-s ${spoof family} -j DROP"
    "-j RETURN"
  ];
  ports =
    protocol: ranges:
    lib.concatLists (
      lib.mapAttrsToList (
        iface: settings:
        map (
          p:
          "-p ${protocol} --dport ${
            if ranges then "${toString p.from}:${toString p.to}" else toString p
          } -j nixos-fw-accept"
          + lib.optionalString (iface != "default") " -i ${iface}"
        ) settings.${"allowed${lib.toUpper protocol}Port${if ranges then "Ranges" else "s"}"}
      ) fw.allInterfaces
    );
  native = family: {
    "dancer-ts-input" = guard family;
    "nixos-fw-accept" = [ "-j ACCEPT" ];
    "nixos-fw-refuse" =
      if fw.rejectPackets then
        [
          "-p tcp ! --syn -j REJECT --reject-with tcp-reset"
          "-j REJECT"
        ]
      else
        [ "-j DROP" ];
    "nixos-fw-log-refuse" =
      lib.optional fw.logRefusedConnections "-p tcp --syn -j LOG --log-level info --log-prefix 'refused connection: '"
      ++ lib.optionals (fw.logRefusedPackets && !fw.logRefusedUnicastsOnly) [
        "-m pkttype --pkt-type broadcast -j LOG --log-level info --log-prefix 'refused broadcast: '"
        "-m pkttype --pkt-type multicast -j LOG --log-level info --log-prefix 'refused multicast: '"
      ]
      ++ [ "-m pkttype ! --pkt-type unicast -j nixos-fw-refuse" ]
      ++ lib.optional fw.logRefusedPackets "-j LOG --log-level info --log-prefix 'refused packet: '"
      ++ [ "-j nixos-fw-refuse" ];
    "nixos-fw" = [
      "-j dancer-ts-input"
    ]
    ++ lib.optional (family == 4) "-p tcp --dport 22 -s 192.168.68.0/22 -j nixos-fw-accept"
    ++ [ "-p tcp --dport 22 -j REJECT --reject-with tcp-reset" ]
    ++ map (i: "-i ${i} -j nixos-fw-accept") fw.trustedInterfaces
    ++ [ "${state} -j nixos-fw-accept" ]
    ++ ports "tcp" false
    ++ ports "tcp" true
    ++ ports "udp" false
    ++ ports "udp" true
    ++ map (r: lib.replaceStrings [ "-j ACCEPT" ] [ "-j nixos-fw-accept" ] r) (icmp family)
    ++ lib.optional (family == 6) "-d fe80::/64 -p udp --dport 546 -j nixos-fw-accept"
    ++ [ "-j nixos-fw-log-refuse" ];
  };
  rpfilter =
    family:
    [
      (
        "-m rpfilter --validmark "
        + lib.optionalString (fw.checkReversePath == "loose") "--loose "
        + "-j RETURN"
      )
    ]
    ++ lib.optionals (family == 4) [
      "-p udp --sport 67 --dport 68 -j RETURN"
      "-s 0.0.0.0 -d 255.255.255.255 -p udp --sport 68 --dport 67 -j RETURN"
    ]
    ++ lib.optional fw.logReversePathDrops "-j LOG --log-level info --log-prefix 'rpfilter drop: '"
    ++ [ "-j DROP" ];
  policy = pkgs.writeText "dancer-firewall-policy.json" (
    builtins.toJSON {
      families =
        map
          (family: {
            tool = "${fw.package}/bin/${if family == 4 then "iptables" else "ip6tables"}";
            hold = hold family;
            native = native family;
            rpfilter = rpfilter family;
          })
          [
            4
            6
          ];
    }
  );
  action =
    name:
    pkgs.writeShellScript "dancer-firewall-${name}" ''
      exec ${pkgs.python3}/bin/python3 ${./dancer-firewall-lifecycle.py} ${policy} ${name}
    '';
  install = action "install";
  release = action "release";
in
{
  assertions = [
    {
      assertion =
        fw.enable
        && fw.backend == "iptables"
        && !config.networking.nftables.enable
        && config.networking.enableIPv6
        && fw.checkReversePath != false
        && lib.elem 41641 fw.allowedUDPPorts
        && fw.trustedInterfaces == [ "lo" ];
      message = "Dancer lifecycle guard requires the reviewed dual-stack iptables endpoint policy, loopback-only trust, rpfilter and UDP 41641";
    }
  ];

  # The pinned unitOption merger coerces the native string command into this
  # ordered list. Never use preStop: it would conflict with native ExecStop.
  # Native commands are retained, not copied or recursively overridden.
  systemd.services.firewall.serviceConfig = {
    ExecStartPre = lib.mkBefore [ install ];
    ExecStartPost = lib.mkAfter [ release ];
    ExecReload = lib.mkMerge [
      (lib.mkBefore [ install ])
      (lib.mkAfter [ release ])
    ];
    ExecStop = lib.mkBefore [ install ];
  };
}
