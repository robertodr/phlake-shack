{ pkgs }:

pkgs.testers.runNixOSTest {
  name = "ssh-lan-unrestricted-red";

  nodes = {
    server =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.netcat-openbsd
          pkgs.openssh
        ];

        services.openssh = {
          enable = true;
          openFirewall = true;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            PermitRootLogin = "no";
          };
        };

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
              if ${pkgs.iproute2}/bin/ip address show dev eth1 | grep -q "10.23.0.20/24"; then
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
    start_all()
    server.wait_for_unit("sshd.service")
    client.wait_for_unit("network-online.target")

    client.succeed("nc -z -s 192.168.68.20 -w 3 192.168.68.10 22")
    client.succeed("nc -z -s 192.168.69.20 -w 3 192.168.68.10 22")

    # Deliberate RED expectation: unrestricted OpenSSH firewall opening makes
    # outsider TCP/22 reachable, so this denial assertion must fail.
    client.fail("nc -z -s 10.23.0.20 -w 3 192.168.68.10 22")
  '';
}
