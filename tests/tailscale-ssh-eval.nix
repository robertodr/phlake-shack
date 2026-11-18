{ pkgs, self }:
let
  inherit (pkgs) lib;
  c = self.nixosConfigurations.dancer.config;
  k = self.nixosConfigurations.kellanved.config;
  # Same-checkout module comparison, NOT the absent private host baseline.
  # Remove only the approved client addition to verify firewall/auth/forwarding
  # are unaffected; do not invent a replacement historical snapshot.
  originalClient =
    (self.nixosConfigurations.kellanved.extendModules {
      modules = [
        { disabledModules = [ ../systems/profiles/services/tailscale/travelling-client.nix ]; }
      ];
    }).config;
  clientFirewall = config: {
    inherit (config.networking.firewall)
      enable
      allowedTCPPorts
      allowedUDPPorts
      allowedTCPPortRanges
      allowedUDPPortRanges
      trustedInterfaces
      checkReversePath
      extraCommands
      extraStopCommands
      interfaces
      ;
  };
  ts = c.services.tailscale;
  fw = c.networking.firewall;
  flags = [
    "--netfilter-mode=off"
    "--ssh=false"
    "--accept-routes=false"
    "--advertise-exit-node=false"
    "--advertise-routes="
    "--exit-node="
  ];
  approvedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICJ9IOPT5M3d01EAiSbDV7fCpqO2mEqH2ibbZoTSfZ+H kellanved"
  ];
  state =
    config:
    lib.filter (
      d: d.directory == "/var/lib/tailscale"
    ) config.environment.persistence."/persist".directories;
  privateState =
    config:
    builtins.length (state config) == 1
    && lib.all (d: d.user == "root" && d.group == "root" && d.mode == "0700") (state config);
  # lib.hasInfix uses a regex; discard only the needle's store context, not
  # its value. The assertion still compares the exact generated invocation.
  has = needle: lib.hasInfix (builtins.unsafeDiscardStringContext needle);
  setScript = c.systemd.services.tailscaled-set.script;
  node = self.deploy.nodes.dancer;
  unit = c.systemd.services.firewall.serviceConfig;
  commands = key: lib.toList (unit.${key} or [ ]);
  lifecycleName = name: command: has "dancer-firewall-${name}" command;
  check = name: pass: { inherit name pass; };
  checks = [
    (check "all-Dancer-NixOS-assertions" (lib.all (a: a.assertion) c.assertions))
    (check "Dancer-endpoint-service" (
      ts.enable
      && ts.interfaceName == "tailscale0"
      && ts.port == 41641
      && ts.openFirewall
      && lib.elem 41641 fw.allowedUDPPorts
      && ts.useRoutingFeatures == "none"
    ))
    (check "interactive-enrollment-only" (
      ts.authKeyFile == null
      && ts.extraUpFlags == [ ]
      && ts.extraDaemonFlags == [ ]
      && !(c.systemd.services ? tailscaled-autoconnect)
    ))
    (check "exact-safe-preferences-in-generated-set-service" (
      ts.extraSetFlags == flags
      && has "${lib.getExe ts.package} set ${lib.escapeShellArgs flags}" setScript
      && c.systemd.services.tailscaled-set.serviceConfig.Type == "oneshot"
      && lib.elem "tailscaled.service" c.systemd.services.tailscaled-set.after
      && lib.elem "multi-user.target" c.systemd.services.tailscaled-set.wantedBy
    ))
    (check "fail-closed-lifecycle-wraps-native-commands-in-order" (
      lib.length (commands "ExecStartPre") == 1
      && lifecycleName "install" (builtins.head (commands "ExecStartPre"))
      && lib.length (commands "ExecStartPost") == 1
      && lifecycleName "release" (builtins.head (commands "ExecStartPost"))
      && lib.length (commands "ExecReload") == 3
      && lifecycleName "install" (builtins.elemAt (commands "ExecReload") 0)
      && has "firewall-reload" (builtins.elemAt (commands "ExecReload") 1)
      && lib.hasPrefix "@" (builtins.elemAt (commands "ExecReload") 1)
      && lifecycleName "release" (builtins.elemAt (commands "ExecReload") 2)
      && lib.length (commands "ExecStop") == 2
      && lifecycleName "install" (builtins.head (commands "ExecStop"))
      && lib.hasPrefix "@" (builtins.elemAt (commands "ExecStop") 1)
      && !lib.any (lifecycleName "install") (
        lib.toList k.systemd.services.firewall.serviceConfig.ExecStop
      )
    ))
    (check "kernel-forwarding-off" (
      c.boot.kernel.sysctl."net.ipv4.ip_forward" == 0
      && c.boot.kernel.sysctl."net.ipv6.conf.all.forwarding" == 0
    ))
    (check "single-private-persistent-state-and-host-keys" (
      privateState c
      && c.fileSystems."/persist".neededForBoot
      && lib.all (name: lib.any (f: f.file == name) c.environment.persistence."/persist".files) [
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_rsa_key"
      ]
      && lib.any (
        m: m.where == "/var/lib/tailscale" && m.what == "/persist/var/lib/tailscale"
      ) c.systemd.mounts
    ))
    (check "OpenSSH-authentication-and-exact-approved-key-preserved" (
      c.services.openssh.enable
      && !c.services.openssh.openFirewall
      && c.services.openssh.settings.PermitRootLogin == "no"
      && !c.services.openssh.settings.PasswordAuthentication
      && !c.services.openssh.settings.KbdInteractiveAuthentication
      && c.services.openssh.settings.PubkeyAuthentication
      && c.users.users.roberto.openssh.authorizedKeys.keys == approvedKeys
    ))
    (check "no-global-SSH-or-interface-trust" (
      fw.enable
      && !c.networking.nftables.enable
      && !lib.elem 22 fw.allowedTCPPorts
      && !lib.any (r: r.from <= 22 && r.to >= 22) fw.allowedTCPPortRanges
      && lib.all (i: i == "lo") fw.trustedInterfaces
      && fw.checkReversePath != false
    ))
    (check "LAN-policy-retained-before-appended-guard-installation" (
      has "-s 192.168.68.0/22 -j nixos-fw-accept" fw.extraCommands
      && has "ip6tables -w -I nixos-fw 1 -p tcp --dport 22 -j REJECT" fw.extraCommands
      &&
        builtins.length (
          lib.splitString "-s 192.168.68.0/22 -j nixos-fw-accept" (
            builtins.head (lib.splitString "for tool in iptables ip6tables" fw.extraCommands)
          )
        ) == 2
    ))
    (check "dual-stack-owned-guard-and-cleanup" (
      lib.all (s: has s fw.extraCommands) [
        "for tool in iptables ip6tables"
        "-A dancer-ts-input -i lo -j RETURN"
        "-A dancer-ts-input -i tailscale0 -p tcp --dport 22 -j nixos-fw-accept"
        "--ctstate ESTABLISHED,RELATED -j RETURN"
        "-i tailscale0 -p icmp -j RETURN"
        "-i tailscale0 -p ipv6-icmp -j RETURN"
        "-A dancer-ts-input -i tailscale0 -j DROP"
        "-s 100.64.0.0/10 -j DROP"
        "-s fd7a:115c:a1e0::/48 -j DROP"
        "-I nixos-fw 1 -j dancer-ts-input"
      ]
      && lib.all (s: has s fw.extraStopCommands) [
        "-D nixos-fw -j dancer-ts-input"
        "-F dancer-ts-input"
        "-X dancer-ts-input"
      ]
      && !has "-j ts-input" fw.extraCommands
    ))
    (check "Kellanved-is-a-separate-user-owned-client" (
      k.services.tailscale.enable
      && privateState k
      && k.services.tailscale.authKeyFile == null
      && k.services.tailscale.extraSetFlags == [ "--ssh=false" ]
      && k.services.tailscale.extraUpFlags == [ ]
      && k.services.tailscale.extraDaemonFlags == [ ]
      && !k.services.tailscale.openFirewall
      && k.services.tailscale.useRoutingFeatures == "none"
      && !has "dancer-ts-input" k.networking.firewall.extraCommands
      && !has "192.168.68.0/22" k.networking.firewall.extraCommands
      && k.services.openssh.openFirewall
    ))
    (check "client-addition-preserves-existing-firewall-auth-and-forwarding" (
      clientFirewall k == clientFirewall originalClient
      && k.services.openssh.settings == originalClient.services.openssh.settings
      &&
        k.users.users.roberto.openssh.authorizedKeys.keys
        == originalClient.users.users.roberto.openssh.authorizedKeys.keys
      && k.boot.kernel.sysctl == originalClient.boot.kernel.sysctl
      && !originalClient.services.tailscale.enable
      && state originalClient == [ ]
    ))
    (check "unapproved-Crokus-LAN-alias-unchanged" (
      self.homeConfigurations."robertoeikas@crokus".config.programs.ssh.settings.dancer.data.hostname
      == "192.168.68.104"
    ))
    (check "shared-LAN-alias-unchanged" (
      c.home-manager.users.roberto.programs.ssh.settings.dancer.data.hostname == "192.168.68.104"
      && k.home-manager.users.roberto.programs.ssh.settings.dancer.data.hostname == "192.168.68.104"
    ))
    (check "deploy-remains-LAN-with-rollback-and-no-agent-forwarding" (
      node.hostname == "192.168.68.104"
      && node.sshUser == "roberto"
      && node.autoRollback
      && node.magicRollback
      && node.interactiveSudo
      &&
        node.sshOpts == [
          "-o"
          "ForwardAgent=no"
        ]
    ))
  ];
  failed = map (x: x.name) (lib.filter (x: !x.pass) checks);
  names = map (x: x.name) checks;
  scriptPath = command: builtins.head (lib.splitString " " (lib.removePrefix "@" command));
in
assert lib.assertMsg (failed == [ ]) "Tailscale checks failed: ${lib.concatStringsSep ", " failed}";
pkgs.runCommand "tailscale-ssh-evaluation"
  {
    passthru.report = {
      scope = "LOCAL_CONFIGURATION_ONLY_NOT_ENROLLMENT_OR_LIVE_PROOF";
      count = builtins.length names;
      passed = names;
      tailscaleVersion = ts.package.version;
      approvedClient = "kellanved";
      deferredClient = "crokus";
    };
    firewallScripts = map scriptPath (
      lib.concatMap commands [
        "ExecStartPre"
        "ExecStart"
        "ExecStartPost"
        "ExecReload"
        "ExecStop"
      ]
    );
    tailscaleSet = scriptPath c.systemd.services.tailscaled-set.serviceConfig.ExecStart;
    nativeBuildInputs = [ pkgs.bash ];
  }
  ''
    for script in $firewallScripts; do
      bash -n "$script"
    done
    bash -n "$tailscaleSet"
    grep -F -- ${lib.escapeShellArg "${lib.getExe ts.package} set ${lib.escapeShellArgs flags}"} "$tailscaleSet"
    printf '%s\n' '${builtins.toJSON names}' > "$out"
  ''
