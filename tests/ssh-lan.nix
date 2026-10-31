{
  pkgs,
  pkgsUnstable ? pkgs,
}:

pkgs.testers.runNixOSTest {
  name = "ssh-lan";

  nodes = {
    server =
      {
        lib,
        pkgs,
        ...
      }:
      {
        _module.args.pkgsUnstable = pkgsUnstable;
        imports = [
          ../systems/profiles/services/openssh/lan-only.nix
          ../systems/profiles/virtualisation/docker
        ];

        environment.systemPackages = [
          pkgs.docker-client
          pkgs.iptables
          pkgs.openssh
          pkgs.python3
        ];

        # The production Docker profile uses btrfs storage. The VM root is not a
        # production btrfs filesystem, so force a VM-only supported driver while
        # still importing and exercising the production socket-activated Docker module.
        virtualisation.docker.storageDriver = lib.mkForce "overlay2";

        networking = {
          useDHCP = false;
          interfaces.eth1 = {
            ipv4.addresses = [
              {
                address = "192.168.68.10";
                prefixLength = 22;
              }
              {
                address = "10.23.0.10";
                prefixLength = 24;
              }
            ];
            ipv6.addresses = [
              {
                address = "fd68::10";
                prefixLength = 64;
              }
            ];
          };
        };

        users = {
          groups.roberto = { };
          users.roberto = {
            isNormalUser = true;
            group = "roberto";
            extraGroups = [ "users" ];
            home = "/home/roberto";
            createHome = true;
            password = "test-only-password";
          };
        };

        virtualisation.vlans = [ 1 ];
      };

    client =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.iproute2
          pkgs.netcat-openbsd
          pkgs.openssh
          pkgs.sshpass
        ];

        networking = {
          useDHCP = false;
          interfaces.eth1 = {
            ipv4.addresses = [
              {
                address = "192.168.68.20";
                prefixLength = 22;
              }
              {
                address = "192.168.69.20";
                prefixLength = 22;
              }
              {
                address = "10.23.0.20";
                prefixLength = 24;
              }
            ];
            ipv6.addresses = [
              {
                address = "fd68::20";
                prefixLength = 64;
              }
            ];
          };
        };

        systemd.services.wait-for-test-lan = {
          description = "Wait for the test LAN addresses";
          before = [ "network-online.target" ];
          wantedBy = [ "network-online.target" ];
          serviceConfig.Type = "oneshot";
          script = ''
            for _ in $(seq 1 30); do
              if ${pkgs.iproute2}/bin/ip address show dev eth1 | grep -q "192.168.68.20/22"; then
                exit 0
              fi
              sleep 1
            done
            exit 1
          '';
        };
        systemd.targets.network-online.wantedBy = [ "multi-user.target" ];

        virtualisation.vlans = [ 1 ];
      };
  };

  testScript = ''
    import shlex

    start_all()
    server.wait_for_unit("sshd.service")
    client.wait_for_unit("network-online.target")

    server.wait_for_unit("docker.socket")
    server.succeed("systemctl is-active docker.socket")
    server.succeed("docker version >/tmp/docker-version")
    server.succeed("systemctl is-active docker.service")
    server.succeed("docker info --format '{{.Driver}}' | grep -Fx overlay2")

    server.succeed("iptables -S INPUT > /tmp/input4.before")
    server.succeed("ip6tables -S INPUT > /tmp/input6.before")
    server.succeed("iptables -S DOCKER-USER >/tmp/docker-user.before || true")
    server.succeed("iptables -S DOCKER >/tmp/docker.before || true")
    server.succeed("iptables -S nixos-fw | sed -n '1,3p' | grep -Fx -- '-A nixos-fw -s 192.168.68.0/22 -p tcp -m tcp --dport 22 -j nixos-fw-accept'")
    server.succeed("iptables -S nixos-fw | sed -n '1,3p' | grep -Fx -- '-A nixos-fw -p tcp -m tcp --dport 22 -j REJECT --reject-with tcp-reset'")
    server.succeed("ip6tables -S nixos-fw | sed -n '1,2p' | grep -Fx -- '-A nixos-fw -p tcp -m tcp --dport 22 -j REJECT --reject-with tcp-reset'")
    server.succeed("python3 - <<'PY'\nfrom pathlib import Path\nrules = Path('/tmp/input4.before').read_text().splitlines()\ntry:\n    nixos_fw = next(i for i, rule in enumerate(rules) if rule == '-A INPUT -j nixos-fw')\nexcept StopIteration:\n    raise SystemExit('INPUT does not jump to nixos-fw')\nfor rule in rules[:nixos_fw]:\n    if '--dport 22' in rule and '-j ACCEPT' in rule:\n        raise SystemExit('broad TCP/22 INPUT accept precedes nixos-fw: ' + rule)\nprint('INPUT nixos-fw jump precedes any TCP/22 accept')\nPY")
    server.succeed("python3 - <<'PY'\nfrom pathlib import Path\nrules = Path('/tmp/input6.before').read_text().splitlines()\ntry:\n    nixos_fw = next(i for i, rule in enumerate(rules) if rule == '-A INPUT -j nixos-fw')\nexcept StopIteration:\n    raise SystemExit('IPv6 INPUT does not jump to nixos-fw')\nfor rule in rules[:nixos_fw]:\n    if '--dport 22' in rule and '-j ACCEPT' in rule:\n        raise SystemExit('broad IPv6 TCP/22 INPUT accept precedes nixos-fw: ' + rule)\nprint('IPv6 INPUT nixos-fw jump precedes any TCP/22 accept')\nPY")

    client.succeed("nc -z -s 192.168.68.20 -w 3 192.168.68.10 22")
    client.succeed("nc -z -s 192.168.69.20 -w 3 192.168.68.10 22")
    client.fail("nc -z -s 10.23.0.20 -w 3 192.168.68.10 22")
    client.fail("nc -z -6 -w 3 fd68::10 22")

    client.succeed("ssh-keygen -q -t ed25519 -N \"\" -f /root/test-login")
    public_key = client.succeed("cat /root/test-login.pub").strip()
    server.succeed("install -d -m 700 -o roberto -g users /home/roberto/.ssh")
    server.succeed("printf %s\\\\n " + shlex.quote(public_key) + " > /home/roberto/.ssh/authorized_keys")
    server.succeed("chown roberto:users /home/roberto/.ssh/authorized_keys; chmod 600 /home/roberto/.ssh/authorized_keys")
    server.succeed("install -d -m 700 /root/.ssh")
    server.succeed("printf %s\\\\n " + shlex.quote(public_key) + " > /root/.ssh/authorized_keys")
    server.succeed("chmod 600 /root/.ssh/authorized_keys")

    ssh = "ssh -i /root/test-login -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3"
    client.succeed(ssh + " -b 192.168.68.20 roberto@192.168.68.10 true")
    client.succeed(ssh + " -b 192.168.69.20 roberto@192.168.68.10 true")
    client.fail(ssh + " -b 10.23.0.20 roberto@192.168.68.10 true")
    client.fail(ssh + " -6 roberto@fd68::10 true")
    client.fail(ssh + " -b 192.168.68.20 root@192.168.68.10 true")
    password_ssh = "sshpass -p test-only-password ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3"
    client.fail(password_ssh + " -b 192.168.68.20 roberto@192.168.68.10 true")

    sshd_effective = "sshd -T"
    server.succeed(sshd_effective + " | tr '[:upper:]' '[:lower:]' | grep -Fx 'passwordauthentication no'")
    server.succeed(sshd_effective + " | tr '[:upper:]' '[:lower:]' | grep -Fx 'kbdinteractiveauthentication no'")
    server.succeed(sshd_effective + " | tr '[:upper:]' '[:lower:]' | grep -Fx 'permitrootlogin no'")

    server.succeed("systemctl restart firewall")
    server.succeed("iptables -S INPUT > /tmp/input4.after-restart")
    server.succeed("ip6tables -S INPUT > /tmp/input6.after-restart")
    server.succeed("iptables -S nixos-fw | sed -n '1,3p' | grep -Fx -- '-A nixos-fw -s 192.168.68.0/22 -p tcp -m tcp --dport 22 -j nixos-fw-accept'")
    server.succeed("iptables -S nixos-fw | sed -n '1,3p' | grep -Fx -- '-A nixos-fw -p tcp -m tcp --dport 22 -j REJECT --reject-with tcp-reset'")
    server.succeed("systemctl is-active docker.service")
    client.succeed("nc -z -s 192.168.69.20 -w 3 192.168.68.10 22")
    client.fail("nc -z -s 10.23.0.20 -w 3 192.168.68.10 22")
    client.fail("nc -z -6 -w 3 fd68::10 22")
    client.succeed(ssh + " -b 192.168.69.20 roberto@192.168.68.10 true")
    client.fail(ssh + " -b 10.23.0.20 roberto@192.168.68.10 true")
    client.fail(ssh + " -6 roberto@fd68::10 true")
  '';
}
