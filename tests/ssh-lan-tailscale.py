import re
import shlex

start_all()
for node in (server, client):
    node.wait_for_unit("fixture-echo.service")
    node.wait_until_succeeds("ip -4 addr show dev tailscale0 | grep -F '100.104.0.'")
    node.wait_until_succeeds(
        "ip -6 addr show dev tailscale0 | grep -F 'fd7a:115c:a1e0:1::'"
    )
    node.wait_until_succeeds("! ip -6 addr show | grep -q tentative")
    node.wait_for_open_port(8080)
server.wait_for_unit("sshd.service")
server.succeed("! systemctl is-active tailscaled.service")

# Both spoof source prefixes have physical return routes, even with strict
# rpfilter left enabled. Pin the IPv6 neighbor because otherwise the guard's
# rejection of spoof-prefixed NDP could mask the TCP/UDP ingress assertion.
server.succeed("ip route get 100.105.0.20 | grep -F 'dev eth1'")
server.succeed("ip -6 route get fd7a:115c:a1e0:2::20 | grep -F 'dev eth1'")
client_mac = client.succeed("cat /sys/class/net/eth1/address").strip()
server.succeed(
    "ip -6 neigh replace fd7a:115c:a1e0:2::20 lladdr "
    + client_mac
    + " nud permanent dev eth1"
)
server.succeed(
    "iptables -t mangle -C nixos-fw-rpfilter -m rpfilter --validmark -j RETURN"
)
server.succeed(
    "ip6tables -t mangle -C nixos-fw-rpfilter -m rpfilter --validmark -j RETURN"
)

client.succeed('ssh-keygen -q -t ed25519 -N "" -f /root/test-login')
public_key = client.succeed("cat /root/test-login.pub").strip()
for user, home in (("roberto", "/home/roberto"), ("root", "/root")):
    server.succeed(f"install -d -m 700 -o {user} {home}/.ssh")
    server.succeed(
        "printf '%s\\n' " + shlex.quote(public_key) + f" > {home}/.ssh/authorized_keys"
    )
    server.succeed(
        f"chown {user} {home}/.ssh/authorized_keys; chmod 600 {home}/.ssh/authorized_keys"
    )

# Host-key checking is bypassed only for throwaway, dynamically keyed VM nodes.
# Production aliases/authentication/host-key policy are not changed.
options = " -o ControlMaster=no -o ControlPath=none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3"
ssh = "ssh -i /root/test-login -o BatchMode=yes -o IdentitiesOnly=yes" + options
links = [
    ("100.104.0.20", "100.104.0.10", "100.104.0.0/24"),
    ("fd7a:115c:a1e0:1::20", "fd7a:115c:a1e0:1::10", "fd7a:115c:a1e0:1::/64"),
]


def probe(node, protocol, source, destination, allowed, port=8080):
    command = "python3 /etc/fixture/probe.py " + " ".join(
        shlex.quote(x) for x in (protocol, source, destination, str(port))
    )
    status, output = node.execute(command)
    assert status == (0 if allowed else 1), (command, status, output)


def authenticate(source, destination, user="roberto", allowed=True, command=ssh):
    cmd = command + " -b " + source + " " + user + "@" + destination + " true"
    status, output = client.execute(cmd + " 2>&1")
    if allowed:
        assert status == 0, (cmd, status, output)
    else:
        assert status == 255 and "Permission denied" in output, (cmd, status, output)


def check_rules():
    server.succeed("python3 /etc/fixture/check-rules.py")


def check_hold():
    for tool, source in (
        ("iptables", "100.64.0.0/10"),
        ("ip6tables", "fd7a:115c:a1e0::/48"),
    ):
        lines = server.succeed(tool + " -w -S INPUT").splitlines()
        hooks = [line for line in lines if line.startswith("-A ")]
        assert hooks[0] == "-A INPUT -j dancer-fw-hold", hooks
        assert hooks.count(hooks[0]) == 1, hooks
        assert not any("ts-input" in line for line in hooks), hooks
        server.succeed(tool + " -w -C dancer-fw-hold -i tailscale0 -j DROP")
        server.succeed(tool + " -w -C dancer-fw-hold -s " + source + " -j DROP")
        server.fail(tool + " -w -nL dancer-fw-plan")
        server.succeed(tool + " -w -C OUTPUT -j fixture-unrelated")


def begin_paused(command):
    server.succeed(
        "rm -f /run/fixture-paused /run/fixture-continue /run/fixture-status; touch /run/fixture-pause"
    )
    server.succeed(
        "(if "
        + command
        + "; then result=0; else result=$?; fi; printf '%s\\n' \"$result\" > /run/fixture-status) >/tmp/fixture-job.log 2>&1 &"
    )
    server.wait_for_file("/run/fixture-paused", timeout=120)


def finish_paused(expected=0):
    server.succeed("touch /run/fixture-continue")
    server.wait_for_file("/run/fixture-status", timeout=120)
    result = int(server.succeed("cat /run/fixture-status").strip())
    assert (result == 0) if expected == 0 else (result != 0), server.succeed(
        "cat /tmp/fixture-job.log"
    )
    server.succeed(
        "rm -f /run/fixture-pause /run/fixture-paused /run/fixture-continue /run/fixture-status"
    )


def spoof_drop_count(tool, source, chain="dancer-ts-input"):
    dump = server.succeed(tool + "-save -c")
    match = re.search(
        r"\[(\d+):\d+\] -A " + chain + " -s " + re.escape(source) + r" -j DROP", dump
    )
    assert match, dump
    return int(match.group(1))


def traffic_matrix(held=False):
    for source in ("192.168.68.20", "192.168.69.20"):
        authenticate(source, "192.168.68.10")
    # Physical outsiders: distinguish a firewall rejection from SSH auth denial.
    for source, destination in (("10.23.0.20", "10.23.0.10"), ("fd68::20", "fd68::10")):
        status, output = client.execute(
            ssh + " -b " + source + " roberto@" + destination + " true 2>&1"
        )
        assert status == 255 and "Connection refused" in output, (status, output)
        for protocol in ("tcp", "udp"):
            probe(client, protocol, source, destination, not held)
        probe(client, "udp", source, destination, True, port=41641)
    for source, destination, _ in links:
        probe(client, "udp", source, destination, False, port=41641)
        authenticate(source, destination)
        authenticate(source, destination, user="root", allowed=False)
        for method in ("password", "keyboard-interactive"):
            command = (
                "sshpass -p test-only-password ssh -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 -o PreferredAuthentications="
                + method
                + options
            )
            authenticate(source, destination, allowed=False, command=command)
        for protocol in ("tcp", "udp"):
            probe(client, protocol, source, destination, False)
            # Inbound replies through tailscale0 must return to established
            # handling, not hit the guard's new-connection DROP.
            probe(server, protocol, destination, source, True)
        server.succeed("ping -c 1 -W 3 -I " + destination + " " + source)
        client.succeed("ping -c 1 -W 3 -I " + source + " " + destination)
        # Local Tailscale source addresses on lo are explicitly exempt from
        # spoofing checks, without making any other interface trusted.
        probe(server, "tcp", destination, destination, True)
    for tool, cidr, source, destination in [
        ("iptables", "100.64.0.0/10", "100.105.0.20", "10.23.0.10"),
        ("ip6tables", "fd7a:115c:a1e0::/48", "fd7a:115c:a1e0:2::20", "fd68::10"),
    ]:
        for protocol in ("tcp", "udp"):
            chain = "dancer-fw-hold" if held else "dancer-ts-input"
            before = spoof_drop_count(tool, cidr, chain)
            probe(client, protocol, source, destination, False)
            # Prove packets reached THIS guard, not just an rpfilter/NDP drop.
            assert spoof_drop_count(tool, cidr, chain) > before


def recreate_detached_chains(first=False):
    for tool in ("iptables", "ip6tables"):
        if not first:
            server.succeed(f"{tool} -w -F ts-input; {tool} -w -X ts-input")
        server.succeed(
            f"{tool} -w -N ts-input; {tool} -w -A ts-input -i tailscale0 -j ACCEPT"
        )
        if first:
            server.succeed(
                f"{tool} -w -N fixture-unrelated; {tool} -w -A fixture-unrelated -j RETURN; {tool} -w -A OUTPUT -j fixture-unrelated"
            )


def negative_control():
    # Isolated expected failure inside a PASSING test: recreate the original
    # Tailscale-owned early INPUT accept, in each address family independently.
    for tool, (source, destination, _) in zip(("iptables", "ip6tables"), links):
        server.succeed(f"{tool} -w -I INPUT 1 -j ts-input")
        try:
            server.fail("python3 /etc/fixture/check-rules.py")
            for protocol in ("tcp", "udp"):
                # The exact denial oracle must now fail, with a successful
                # request/reply proving it is not just a checker-string failure.
                try:
                    probe(client, protocol, source, destination, False)
                except AssertionError:
                    pass
                else:
                    raise AssertionError(
                        "negative control failed to detect exposed canary"
                    )
                probe(client, protocol, source, destination, True)
        finally:
            server.succeed(f"{tool} -w -D INPUT -j ts-input")
            # Negative-control UDP replies create conntrack state; remove only
            # these fixture canary flows before testing NEW connections again.
            server.succeed(
                "conntrack -D -p udp --dport 8080 >/dev/null 2>&1 || test $? = 1"
            )
        check_rules()
        for protocol in ("tcp", "udp"):
            probe(client, protocol, source, destination, False)


for setting in (
    "permitrootlogin no",
    "passwordauthentication no",
    "kbdinteractiveauthentication no",
    "pubkeyauthentication yes",
):
    server.succeed(
        "sshd -T | tr '[:upper:]' '[:lower:]' | grep -Fx " + shlex.quote(setting)
    )

recreate_detached_chains(first=True)
for phase in ("initial", "reload", "restart", "detached-chain-recreation"):
    with subtest(phase):
        if phase == "reload":
            # Twice to expose rule/reference accumulation.
            server.succeed("systemctl reload firewall; systemctl reload firewall")
        elif phase == "restart":
            server.succeed("systemctl restart firewall; systemctl restart firewall")
        elif phase == "detached-chain-recreation":
            recreate_detached_chains()
        check_rules()
        traffic_matrix()
        negative_control()
        check_rules()
        traffic_matrix()

# Original cleanup-skeleton negative control, isolated to these VMs: invoke
# the preserved native script without lifecycle wrappers and pause it exactly
# after production cleanup. The old main chain now exposes global canaries.
with subtest("unguarded-reload-transition-negative-control"):
    begin_paused("/etc/fixture/native-firewall-reload")
    server.fail("python3 /etc/fixture/check-rules.py")
    for source, destination, _ in links:
        for protocol in ("tcp", "udp"):
            try:
                probe(client, protocol, source, destination, False)
            except AssertionError:
                pass
            else:
                raise AssertionError("old cleanup skeleton did not expose canary")
            probe(client, protocol, source, destination, True)
    finish_paused()
    server.succeed("conntrack -D -p udp --dport 8080 >/dev/null 2>&1 || test $? = 1")
    check_rules()
    traffic_matrix()

for operation in ("reload", "restart"):
    with subtest("paused-" + operation + "-transition"):
        begin_paused("systemctl " + operation + " firewall")
        check_hold()
        traffic_matrix(held=True)
        # Repeated install must not flush an attached chain or reset counters.
        before = spoof_drop_count("iptables", "100.64.0.0/10", "dancer-fw-hold")
        server.succeed("/etc/fixture/lifecycle-install; /etc/fixture/lifecycle-install")
        assert (
            spoof_drop_count("iptables", "100.64.0.0/10", "dancer-fw-hold")
            >= before
            > 0
        )
        check_hold()
        finish_paused()
        check_rules()
        traffic_matrix()

with subtest("injected-rebuild-failure-retains-recovery-guard"):
    server.succeed("touch /run/fixture-fail-start")
    begin_paused("systemctl reload firewall")
    check_hold()
    traffic_matrix(held=True)
    finish_paused(expected=1)
    check_hold()
    traffic_matrix(held=True)
    server.succeed("rm /run/fixture-fail-start; systemctl restart firewall")
    check_rules()
    traffic_matrix()

with subtest("guard-tamper-and-both-families-validated-before-release"):
    server.succeed("/etc/fixture/lifecycle-install")
    check_hold()
    server.succeed("iptables -w -A dancer-fw-hold -j RETURN")
    before = server.succeed("iptables -w -S dancer-fw-hold")
    server.fail("/etc/fixture/lifecycle-install")
    assert server.succeed("iptables -w -S dancer-fw-hold") == before
    server.succeed("iptables -w -D dancer-fw-hold -j RETURN")
    # A mismatch only in IPv6 must keep BOTH IPv4 and IPv6 caps installed.
    server.succeed("ip6tables -w -A nixos-fw -p udp --dport 8081 -j ACCEPT")
    server.fail("/etc/fixture/lifecycle-release")
    check_hold()
    traffic_matrix(held=True)
    server.succeed("ip6tables -w -D nixos-fw -p udp --dport 8081 -j ACCEPT")
    server.succeed("/etc/fixture/lifecycle-release")
    check_rules()

with subtest("explicit-stop-cleanup-and-start"):
    server.succeed("systemctl stop firewall")
    for tool in ("iptables", "ip6tables"):
        server.fail(f"{tool} -w -nL dancer-ts-input")
        # Stopping must remove the owned jump AND chain, but leave unrelated
        # chains and detached simulated Tailscale chains untouched.
        server.fail(f"{tool} -w -C nixos-fw -j dancer-ts-input")
        server.succeed(f"{tool} -w -C ts-input -i tailscale0 -j ACCEPT")
        server.succeed(f"{tool} -w -C OUTPUT -j fixture-unrelated")
        server.succeed(f"{tool} -w -C fixture-unrelated -j RETURN")
    check_hold()
    traffic_matrix(held=True)
    server.succeed("systemctl start firewall")
    check_rules()
    traffic_matrix()
