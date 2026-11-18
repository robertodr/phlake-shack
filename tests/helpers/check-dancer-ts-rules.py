"""Strict VM rule/lifecycle oracle; intentionally rejects the old INPUT bypass."""

import shlex
import subprocess


def rules(tool, chain=None):
    command = [tool, "-w", "-S"]
    if chain:
        command.append(chain)
    return [
        shlex.split(line)
        for line in subprocess.check_output(command, text=True).splitlines()
        if line.startswith("-A ")
    ]


def normalized(rule):
    result = rule.copy()
    if "--ctstate" in result:
        index = result.index("--ctstate") + 1
        result[index] = ",".join(sorted(result[index].split(",")))
    return result


for tool, source, icmp in [
    ("iptables", "100.64.0.0/10", "icmp"),
    ("ip6tables", "fd7a:115c:a1e0::/48", "ipv6-icmp"),
]:
    all_rules = rules(tool)
    # No pre-firewall hook, equivalent early ACCEPT, or later active ts-input
    # hook is approved. The isolated fixture needs precisely this INPUT path.
    assert rules(tool, "INPUT") == [["-A", "INPUT", "-j", "nixos-fw"]], all_rules
    assert not any("dancer-fw-hold" in r for r in all_rules), all_rules
    assert not any("dancer-fw-plan" in r for r in all_rules), all_rules
    assert not any("ts-input" in r[2:] for r in all_rules), all_rules
    main = rules(tool, "nixos-fw")
    assert main[0] == ["-A", "nixos-fw", "-j", "dancer-ts-input"], main
    references = [r for r in all_rules if "dancer-ts-input" in r[2:]]
    assert references == [main[0]], references
    expected = [
        "-i lo -j RETURN",
        "-i tailscale0 -p tcp -m tcp --dport 22 -j nixos-fw-accept",
        "-i tailscale0 -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN",
        f"-i tailscale0 -p {icmp} -j RETURN",
        "-i tailscale0 -j DROP",
        f"-s {source} -j DROP",
        "-j RETURN",
    ]
    expected = [
        normalized(["-A", "dancer-ts-input"] + shlex.split(r)) for r in expected
    ]
    actual = [normalized(r) for r in rules(tool, "dancer-ts-input")]
    assert actual == expected, (tool, actual, expected)
    lan = (
        [
            [
                "-A",
                "nixos-fw",
                "-s",
                "192.168.68.0/22",
                "-p",
                "tcp",
                "-m",
                "tcp",
                "--dport",
                "22",
                "-j",
                "nixos-fw-accept",
            ]
        ]
        if tool == "iptables"
        else []
    )
    reject = [
        "-A",
        "nixos-fw",
        "-p",
        "tcp",
        "-m",
        "tcp",
        "--dport",
        "22",
        "-j",
        "REJECT",
        "--reject-with",
        "tcp-reset",
    ]
    assert main[1 : 2 + len(lan)] == lan + [reject], main
    assert rules(tool, "ts-input") == [
        ["-A", "ts-input", "-i", "tailscale0", "-j", "ACCEPT"]
    ]
    assert rules(tool, "fixture-unrelated") == [
        ["-A", "fixture-unrelated", "-j", "RETURN"]
    ]
    assert rules(tool, "OUTPUT").count(["-A", "OUTPUT", "-j", "fixture-unrelated"]) == 1
print("dual-stack guard ordering, unique references, no bypass, unrelated rules intact")
