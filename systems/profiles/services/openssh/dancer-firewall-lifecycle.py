"""Dancer-only fail-closed lifecycle guard. Never mutate an attached ruleset."""

import fcntl
import json
import os
import shlex
import subprocess
import sys

HOLD = "dancer-fw-hold"
PLAN = "dancer-fw-plan"


def run(tool, *args, table="filter"):
    return subprocess.check_output(
        [tool, "-w", "-t", table, *args], text=True, stderr=subprocess.STDOUT
    )


def rules(tool, chain=None, table="filter"):
    args = ("-S", chain) if chain else ("-S",)
    return [shlex.split(line) for line in run(tool, *args, table=table).splitlines()]


def entries(tool, chain, table="filter"):
    return [r[2:] for r in rules(tool, chain, table) if r[0] == "-A"]


def references(tool, chain, table="filter"):
    return [
        r
        for r in rules(tool, table=table)
        if r[0] == "-A"
        and any(r[i] in ("-j", "-g") and r[i + 1] == chain for i in range(len(r) - 1))
    ]


def exists(tool, chain, table="filter"):
    return any(r[:2] == ["-N", chain] for r in rules(tool, table=table))


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def canonical(tool, specs, table="filter"):
    # Only this owned, unreferenced staging chain may be flushed. Asking the
    # pinned tool to canonicalize handles protocol modules, ICMP type names,
    # conntrack ordering and address masks without weakening comparisons.
    require(not references(tool, PLAN, table), "staging chain unexpectedly referenced")
    if exists(tool, PLAN, table):
        run(tool, "-F", PLAN, table=table)
    else:
        run(tool, "-N", PLAN, table=table)
    try:
        for spec in specs:
            run(tool, "-A", PLAN, *shlex.split(spec), table=table)
        return entries(tool, PLAN, table)
    finally:
        run(tool, "-F", PLAN, table=table)
        run(tool, "-X", PLAN, table=table)


def verify_hold(family):
    tool = family["tool"]
    expected = canonical(tool, family["hold"])
    require(exists(tool, HOLD), "lifecycle guard absent")
    require(
        entries(tool, HOLD) == expected, "lifecycle guard differs from reviewed policy"
    )
    require(
        references(tool, HOLD) == [["-A", "INPUT", "-j", HOLD]], "guard hook not unique"
    )
    require(entries(tool, "INPUT")[:1] == [["-j", HOLD]], "guard is not first in INPUT")


def install(family):
    tool = family["tool"]
    expected = canonical(tool, family["hold"])
    # Fail on unexpected rule ownership/order. In particular, never quietly
    # accommodate Tailscale-managed INPUT hooks or other earlier accepts.
    input_rules = entries(tool, "INPUT")
    require(
        input_rules
        in (
            [],
            [["-j", "nixos-fw"]],
            [["-j", HOLD]],
            [["-j", HOLD], ["-j", "nixos-fw"]],
            [["-j", HOLD], ["-j", "nixos-fw"], ["-j", "nixos-drop"]],
            [["-j", HOLD], ["-j", "nixos-drop"]],
        ),
        "unexpected INPUT rules; lifecycle operation refused",
    )
    if exists(tool, HOLD):
        require(
            entries(tool, HOLD) == expected,
            "existing guard policy differs; not modified",
        )
        require(
            references(tool, HOLD) in ([], [["-A", "INPUT", "-j", HOLD]]),
            "existing guard has unexpected references",
        )
    else:
        run(tool, "-N", HOLD)
        # Built detached; a failure aborts before any native operation runs.
        for spec in family["hold"]:
            run(tool, "-A", HOLD, *shlex.split(spec))
        require(entries(tool, HOLD) == expected, "new guard verification failed")
    if not references(tool, HOLD):
        run(tool, "-I", "INPUT", "1", "-j", HOLD)
    verify_hold(family)


def verify_native(family):
    tool = family["tool"]
    verify_hold(family)
    require(
        entries(tool, "INPUT") == [["-j", HOLD], ["-j", "nixos-fw"]],
        "native INPUT path not restored",
    )
    for chain, specs in family["native"].items():
        expected = canonical(tool, specs)
        require(
            entries(tool, chain) == expected,
            f"native chain {chain} differs from evaluated policy",
        )
    require(
        references(tool, "dancer-ts-input")
        == [["-A", "nixos-fw", "-j", "dancer-ts-input"]],
        "steady guard reference not unique",
    )
    require(not references(tool, "ts-input"), "active Tailscale input hook")
    expected = canonical(tool, family["rpfilter"], table="mangle")
    require(
        entries(tool, "nixos-fw-rpfilter", "mangle") == expected, "rpfilter differs"
    )
    require(
        references(tool, "nixos-fw-rpfilter", "mangle")
        == [["-A", "PREROUTING", "-j", "nixos-fw-rpfilter"]],
        "rpfilter hook not unique",
    )


def main():
    policy_file, action = sys.argv[1:]
    require(action in ("install", "release"), "unknown lifecycle action")
    with open(policy_file, encoding="utf-8") as stream:
        families = json.load(stream)["families"]
    # Serialize our own operations. iptables -w also honors the kernel rule
    # writer lock per command; systemd serializes native unit jobs.
    fd = os.open(
        "/run/dancer-firewall.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600
    )
    with os.fdopen(fd, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if action == "install":
            for family in families:
                install(family)
        else:
            # Validate BOTH families, full native/owned chains and rpfilter,
            # before removing either hook. Any error leaves both caps in place.
            for family in families:
                verify_native(family)
            for path in (
                "/proc/sys/net/ipv4/ip_forward",
                "/proc/sys/net/ipv6/conf/all/forwarding",
            ):
                with open(path, encoding="ascii") as stream:
                    require(
                        stream.read().strip() == "0", "forwarding unexpectedly enabled"
                    )
            for family in families:
                tool = family["tool"]
                run(tool, "-D", "INPUT", "-j", HOLD)
                # Now off-path and unreferenced; never flush an attached cap.
                require(
                    not references(tool, HOLD), "unexpected remaining guard reference"
                )
                run(tool, "-F", HOLD)
                run(tool, "-X", HOLD)
        print(f"Dancer firewall lifecycle {action}: both address families verified")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(
            f"Dancer firewall lifecycle failed; protection not released: {error}",
            file=sys.stderr,
        )
        sys.exit(1)
