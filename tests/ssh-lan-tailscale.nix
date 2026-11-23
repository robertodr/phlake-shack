{ pkgs }:
let
  address = value: prefixLength: {
    address = value;
    inherit prefixLength;
  };
  common = { pkgs, ... }: {
    environment.systemPackages = [
      pkgs.iptables
      pkgs.conntrack-tools
      pkgs.openssh
      pkgs.python3
      pkgs.sshpass
      pkgs.iproute2
      pkgs.iputils
    ];
    environment.etc = {
      "fixture/echo.py".source = ./helpers/tailscale-echo.py;
      "fixture/probe.py".source = ./helpers/tailscale-probe.py;
      "fixture/check-rules.py".source = ./helpers/check-dancer-ts-rules.py;
    };
    # A second real VM Ethernet link is named tailscale0: packets really enter
    # on it. No dummy-interface/string-only substitute for ingress testing.
    virtualisation.interfaces = {
      eth1.vlan = 1;
      tailscale0.vlan = 2;
    };
    networking.useDHCP = false;
    systemd.services.fixture-echo = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 /etc/fixture/echo.py";
    };
  };
in
pkgs.testers.runNixOSTest {
  name = "ssh-lan-tailscale";
  nodes = {
    server = { config, lib, ... }: {
      imports = [
        common
        ../systems/profiles/services/openssh/lan-and-tailscale.nix
      ];
      environment.etc = {
        "fixture/native-firewall-reload".source = builtins.head (
          lib.splitString " " (
            lib.removePrefix "@" (
              lib.findFirst (lib.hasPrefix "@") (throw "native firewall reload missing") (
                lib.toList config.systemd.services.firewall.serviceConfig.ExecReload
              )
            )
          )
        );
        "fixture/lifecycle-install".source =
          builtins.elemAt config.systemd.services.firewall.serviceConfig.ExecReload 0;
        "fixture/lifecycle-release".source =
          builtins.elemAt config.systemd.services.firewall.serviceConfig.ExecReload 2;
      };
      # Fixture only: a real tailscaled must not compete for the simulated
      # tailscale0 link. This test is NOT real-daemon restart/enrollment proof.
      services.tailscale.enable = lib.mkForce false;
      networking = {
        firewall = {
          # Fixture-only globally open canaries MUST still be blocked on
          # tailscale0, but reachable through the permitted physical path.
          allowedTCPPorts = [ 8080 ];
          allowedUDPPorts = [
            8080
            41641
          ];
          # Deterministic VM-only pause AFTER production cleanup, before the
          # pinned start/rebuild. No sleep-based race or production override.
          extraStopCommands = lib.mkAfter ''
            if test -e /run/fixture-pause; then
              touch /run/fixture-paused
              while ! test -e /run/fixture-continue; do sleep 0.05; done
            fi
          '';
          extraCommands = lib.mkAfter ''
            if test -e /run/fixture-fail-start; then
              echo 'injected VM-only firewall start failure' >&2
              exit 1
            fi
          '';
        };
        interfaces = {
          eth1 = {
            ipv4.addresses = [
              (address "192.168.68.10" 22)
              (address "10.23.0.10" 24)
              (address "100.105.0.10" 24)
            ];
            ipv6.addresses = [
              (address "fd68::10" 64)
              (address "fd7a:115c:a1e0:2::10" 64)
            ];
          };
          tailscale0 = {
            ipv4.addresses = [ (address "100.104.0.10" 24) ];
            ipv6.addresses = [ (address "fd7a:115c:a1e0:1::10" 64) ];
          };
        };
      };
      users = {
        groups.roberto = { };
        users.roberto = {
          isNormalUser = true;
          group = "roberto";
          createHome = true;
          password = "test-only-password";
        };
      };
    };
    client = {
      imports = [ common ];
      networking = {
        firewall = {
          allowedTCPPorts = [ 8080 ];
          allowedUDPPorts = [ 8080 ];
        };
        interfaces = {
          eth1 = {
            ipv4.addresses = [
              (address "192.168.68.20" 22)
              (address "192.168.69.20" 22)
              (address "10.23.0.20" 24)
              (address "100.105.0.20" 24)
            ];
            ipv6.addresses = [
              (address "fd68::20" 64)
              (address "fd7a:115c:a1e0:2::20" 64)
            ];
          };
          tailscale0 = {
            ipv4.addresses = [ (address "100.104.0.20" 24) ];
            ipv6.addresses = [ (address "fd7a:115c:a1e0:1::20" 64) ];
          };
        };
      };
    };
  };
  testScript = builtins.readFile ./ssh-lan-tailscale.py;
}
