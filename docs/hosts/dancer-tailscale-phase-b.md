# Dancer Tailscale: repository-only Phase B report

## Scope and authority

Repository-only Phase B and the separately approved lifecycle correction were
implemented and locally checked on 2026-11-18. **Not deployed, activated,
enrolled, rebooted, or ready for travel.** No commit or push was made during
that initial phase. The owner subsequently authorized scoped publication to a
review branch, including the existing user-modified lockfile. That authorization
does not include live work, which still requires separate approval and the
[handoff](dancer-tailscale-handoff.md) gates.

Approved scope is Dancer as an ordinary OpenSSH server and Kellanved as a
separate user-owned Linux client. Crokus is deferred. The existing approved
SSH key and shared LAN alias are unchanged; no credentials, account policy
export, authentication URL, or placeholder hostname was added to configuration.

The owner confirmed the intended personal tailnet, exact GitHub login identity,
Owner role, MagicDNS enabled, MFA/passkeys and Personal plan. Direct access to
the JSON policy editor worked, so no first-client bootstrap exception was used.
The owner approved all user-owned devices of that identity as the source scope
and confirmed saving the reviewed restrictive tag/TCP-22 policy without errors.
Dancer had never been enrolled. Kellanved's existing LAN public-key SSH works;
Crokus's key prerequisite is deferred. These are user confirmations, not live
independent acceptance results. No client was enrolled by the agent.

## Changed files

- `flake.nix`: register the standalone evaluation and packet checks.
- `systems/x86_64-linux/dancer/default.nix`: import the two server profiles.
- `systems/x86_64-linux/kellanved/default.nix`: import only the client profile
  (plus a nixfmt-only indentation adjustment).
- `systems/profiles/services/tailscale/dancer-ssh.nix`: endpoint preferences,
  UDP opening, forwarding disabled, private persistent state.
- `systems/profiles/services/tailscale/travelling-client.nix`: separately scoped
  client service and state, without changing its existing firewall policy.
- `systems/profiles/services/openssh/lan-and-tailscale.nix`: dual-stack guard.
- `systems/profiles/services/openssh/dancer-firewall-lifecycle.nix` and
  `dancer-firewall-lifecycle.py`: Dancer-only lifecycle command ordering,
  recovery cap and full native/owned-rule validation before release.
- `tests/tailscale-ssh-eval.nix`: standalone checks without the private baseline.
- `tests/ssh-lan-tailscale.nix` and `tests/ssh-lan-tailscale.py`: packet/lifecycle
  fixture and traffic matrix.
- `tests/helpers/check-dancer-ts-rules.py`: strict rule-order/reference oracle.
- `tests/helpers/tailscale-echo.py` and `tests/helpers/tailscale-probe.py`:
  dual-stack TCP/UDP request/reply canaries.
- `tests/impermanence.nix`: synthetic state marker/mount/permission checks.
- `tests/host-invariants.nix`: description only; assertions remain intact.
- `docs/hosts/dancer-install.md`, `dancer-deploy-rs.md`, and
  `dancer-manual-boot-rollback.md`: distinguish repository policy, LAN fallback,
  and separately approved live work.
- `docs/hosts/dancer-tailscale-handoff.md`: link this implementation status.
- This report.

`flake.lock` already had user changes and was not modified by the agent. The
owner separately approved including that exact tested lock in publication; no
additional input update was performed. Those broader input changes are not a
claim of whole-repository or other-host regression coverage.
The LAN-only profile, existing LAN test and deliberately failing red fixture,
storage layout, root rollback, boot policy, and deploy target are unchanged.

## Security and lifecycle review

### Original finding, now corrected with explicit approval

Final inspection found a contradiction between the handoff's lifecycle-safety
requirement and its proposed cleanup skeleton. In the pinned
`nixos/modules/services/networking/firewall-iptables.nix`, reload:

1. Appends `INPUT -> nixos-drop`, behind the existing `INPUT -> nixos-fw`.
2. Runs `extraStopCommands`.
3. Calls the start script, which then detaches/rebuilds `nixos-fw`.

The handoff's cleanup detaches/deletes `dancer-ts-input` in step 2 while the old
main firewall remains reachable. Until step 3 detaches it, its generic allowed
TCP/UDP ports can accept new traffic from `tailscale0` before the later drop
hook. This is not merely lack of atomic replacement: cleanup temporarily
broadens the old policy. The stock stop script also removes the INPUT firewall
hook, so stop/restart does not provide continuous filtering either.

The agent stopped, explained the contradiction, proposed a lifecycle correction,
and obtained explicit approval before implementing it. The VM now reproduces the
old exposure by bypassing only the lifecycle command wrappers and pausing the
native reload immediately after cleanup. TCP/UDP canaries become reachable in
both families, and the denial/rule oracles detect the regression.

The correction retains the settled NixOS-owned steady-state guard and native
firewall scripts. It adds `dancer-fw-hold`, an independent, fully populated,
verified cap inserted first in INPUT **before** native start/reload/stop. Native
start/reload is followed by verification and release; stop or any failed rebuild
leaves the cap installed. Ordered systemd command lists preserve the pinned
native commands without copying their scripts or changing shared modules.

The cap preserves LAN/Tailscale TCP 22, established/related replies, normal
IPv4 echo and IPv6 ICMP exceptions, and physical UDP 41641. It rejects other
physical SSH, drops spoofed tailnet prefixes on physical links, and drops all
other Tailscale ingress. Other physical services can be temporarily unavailable
while held. Loopback returns rather than becoming newly trusted. The cap uses
terminal verdicts, not references to native chains that are about to disappear.

Only detached owned chains (the staging chain, or the cap after detachment)
are flushed. Existing attached cap rules
are compared exactly and never rewritten; unexpected contents/references/order
abort the operation. Release checks BOTH families' complete evaluated native
filter chains, steady guard, rpfilter chains/hooks, and disabled forwarding
before detaching either cap. The installed tools canonicalize verification
specifications in an unreferenced staging chain; this does not relax exact
rule-order comparisons. Gate operations are serialized with a root-only lock.

The expanded test passes at deterministic pauses during reload/restart, after
injected rebuild failure, while stopped, and after restoration. Reinstallation
preserves counters; unexpected cap contents are rejected unchanged. A mismatch
only in IPv6 prevents releasing either family. All tests use isolated VMs, not
an enrolled daemon or production hosts.

### Settled-state configuration and results

Dancer uses Tailscale **netfilter mode off**; NixOS alone owns its kernel filter
rules. Its UDP 41641 opening is not a global TCP-22 opening. Tailscale SSH,
route acceptance/advertisement, exit-node use/advertisement and kernel forwarding
are disabled. There is no auth-key enrollment or automatic `tailscale up`.
`tailscaled-set` is not a pre-start migration mechanism; first enrollment must
use the handoff's explicit safe flags and must stop if existing state is found.

In both IPv4 and IPv6, the first `nixos-fw` rule enters `dancer-ts-input`:

1. Loopback returns to normal NixOS policy.
2. TCP 22 on `tailscale0` enters `nixos-fw-accept`.
3. Other established/related traffic and the appropriate ICMP family return to
   normal policy, not unconditional acceptance.
4. All remaining Tailscale-interface traffic drops before global allowances.
5. Tailscale source prefixes on other interfaces drop.
6. Remaining traffic returns to the retained LAN-only SSH rules.

The module appends its installation commands after the LAN profile and inserts
its jump at position one. It creates/flushes only its own chain. Security-rule
installation errors are not suppressed. Stop cleanup detaches the owned jump
before flushing/deleting the chain; only absent-rule cleanup is best-effort.
The pinned firewall invokes cleanup before reload and rebuilds `nixos-fw`.
The settled states after repeated reloads/restarts, detached-chain recreation,
and explicit stop/start were tested without duplicate references or damage to
unrelated chains. The additional transition tests above cover the original
intermediate-state defect, but do not prove live enrolled-daemon restart behavior.
Stopping the firewall deliberately retains the restrictive cap; starting it
releases the cap only after full verification. Do not manually flush it to
recover. Unexpected existing rules or a changed cap policy need explicit review.
A rollback to an older configuration without this helper may leave the cap in
place; trusted LAN SSH remains the bounded recovery path, with console backup.

Both approved hosts have exactly one root-owned, mode `0700` persistent
`/var/lib/tailscale` directory. Dancer's existing host-key persistence is retained.
The impermanence VM proves synthetic-marker persistence and permissions through
root rollback, not real node-identity persistence.

Kellanved retains its normal client netfilter integration, no server tag or
server guard, no new global UDP opening, and unchanged existing firewall,
OpenSSH authentication/authorized keys and forwarding sysctls. The evaluation
compares it with the same checkout minus just the new client module; that is
not a fabricated replacement for the absent historical private baseline.
Crokus files and the shared SSH alias were not changed.

## Source and exact local checks

Base HEAD: `ad9db5e0ff869368994749eda5a8453eed4f308a`, plus uncommitted changes.
The existing working-tree lock SHA-256 remained:

```text
c63f3ada56139508ebc3ecd9805e2e44780f5a743e5375f6a6c875b9901d8731
```

The working lock selects Nixpkgs
`f68407657ad294471eb4b2e65d193df26edf729f` and Tailscale **1.104.5**.
The pinned Nixpkgs Tailscale/iptables modules and Tailscale `iptables_runner.go`
were inspected. The package's actual `tailscale version`, `set --help`, and
`up --help` were run; no `up` or `set` action was executed on a live daemon.
All required flags exist in this pinned CLI. Generated firewall and preference
scripts were syntax-checked by the evaluation derivation, which also verifies
the actual generated preference script contains the exact invocation.

Because the implementation includes untracked files, checks used this local-only
`/tmp/dancer-phase-b-local.nix`, not an old Git-filtered implementation or an
unrestricted whole-tree check:

```nix
let
  pinned = builtins.getFlake "git+file:///home/roberto/phlake-shack";
  self = (import /home/roberto/phlake-shack/flake.nix).outputs
    (pinned.inputs // { inherit self; }) // {
      inputs = pinned.inputs;
      outPath = "/home/roberto/phlake-shack";
    };
in self
```

The explicit Git URL resolves locked inputs without copying untracked extras or
`.git`. Module imports read the current implementation directly. Do not replace
that URL with a plain path or `path:.`. This is not an immutable published
source and must **never** be used for deployment. Repeat deployment prechecks
on an independently reviewed, published revision before live maintenance.

These exact report commands passed:

```sh
nix eval --impure --json --file /tmp/dancer-phase-b-local.nix checks.x86_64-linux.tailscale-ssh-eval.report
nix eval --impure --json --file /tmp/dancer-phase-b-local.nix checks.x86_64-linux.deploy-rs-eval.report
nix eval --impure --json --file /tmp/dancer-phase-b-local.nix checks.x86_64-linux.dancer-manual-boot-eval.report
nix eval --impure --json --file /tmp/dancer-phase-b-local.nix checks.x86_64-linux.starship-battery-eval.report
```

The final scoped build command passed, including the approved lifecycle
correction and transition-level regression checks:

```sh
nix build --no-link --impure --file /tmp/dancer-phase-b-local.nix \
  checks.x86_64-linux.tailscale-ssh-eval \
  checks.x86_64-linux.ssh-lan-tailscale \
  checks.x86_64-linux.ssh-lan \
  checks.x86_64-linux.impermanence \
  checks.x86_64-linux.deploy-schema \
  checks.x86_64-linux.deploy-rs-eval \
  checks.x86_64-linux.dancer-manual-boot-eval \
  checks.x86_64-linux.starship-battery-eval
```

| Check | Result and limits |
| --- | --- |
| `tailscale-ssh-eval` | PASS: 16 assertions, including exact lifecycle command ordering, exact key/preferences, generated scripts, persistent mounts, host/client boundaries, LAN deploy settings. |
| `ssh-lan-tailscale` | PASS: real ingress on a second VM link named `tailscale0`; IPv4 `/22` including `.69`, overlay IPv4/IPv6 SSH, physical-outsider rejection, root/password/interactive-auth denial, TCP/UDP canaries, loopback and ICMP, server-initiated replies, spoof-prefix drop counters with strict rpfilter and valid physical return routes. |
| Packet negative controls | PASS: in each family and steady-state lifecycle phase, an unsafe early `INPUT -> ts-input` hook makes TCP/UDP canaries reachable and causes both rule and denial oracles to fail as expected. Removing it restores blocking. This is an expected-failure subtest, not a failing registered check. |
| Packet lifecycle | PASS: steady-state matrices plus deterministic paused reload/restart, old-skeleton negative control, injected rebuild failure with fresh recovery SSH, idempotent cap install, tamper refusal, IPv6-only verification failure retaining both caps, and explicit stopped/start behavior. Steady guards are cleaned up while the independent cap stays installed until native verification succeeds. No real enrolled daemon runs in the fixture. |
| Existing `ssh-lan` | PASS, including the unchanged LAN-only policy and Docker interaction. |
| `impermanence` | PASS: existing rollback checks plus synthetic state marker, bind mount and root `0700`/file `0600` permissions before/after VM rollback. |
| Deploy schema/settings | PASS: schema plus 10 settings assertions; no activation/full-profile deployment check was run. |
| Manual boot | PASS: 31 configuration assertions, not a physical boot test. |
| Battery | PASS: 4 existing configuration assertions. |

Formatting/lint commands used these explicit file sets:

```sh
nixfiles=(
  flake.nix
  systems/x86_64-linux/dancer/default.nix
  systems/x86_64-linux/kellanved/default.nix
  systems/profiles/services/tailscale/dancer-ssh.nix
  systems/profiles/services/tailscale/travelling-client.nix
  systems/profiles/services/openssh/lan-and-tailscale.nix
  systems/profiles/services/openssh/dancer-firewall-lifecycle.nix
  tests/tailscale-ssh-eval.nix tests/ssh-lan-tailscale.nix
  tests/impermanence.nix tests/host-invariants.nix
)
pyfiles=(
  systems/profiles/services/openssh/dancer-firewall-lifecycle.py
  tests/ssh-lan-tailscale.py tests/helpers/check-dancer-ts-rules.py
  tests/helpers/tailscale-echo.py tests/helpers/tailscale-probe.py
)
nixfmt --check "${nixfiles[@]}"
/nix/store/h1yrrgk73z6gkwgq7vmqwdj93v83bn3j-deadnix-1.3.2/bin/deadnix --fail "${nixfiles[@]}"
for file in "${nixfiles[@]}"; do
  /nix/store/bw28anbmpwxnmn6k0zai9a38wj95l7pl-statix-0-unstable-2026-05-14/bin/statix check "$file"
done
/nix/store/h9ixbhand68x7ms8395ffl5fkbjfk660-ruff-0.15.14/bin/ruff check --no-cache --select E9,F63,F7,F82 --ignore F821 "${pyfiles[@]}"
/nix/store/h9ixbhand68x7ms8395ffl5fkbjfk660-ruff-0.15.14/bin/ruff format --check --no-cache "${pyfiles[@]}"
git diff --check
```

Nix formatting, deadnix, Python syntax/name checks (excluding injected test-driver
globals), Python formatting and whitespace checks pass. Ten changed Nix files
are statix-clean. `flake.nix` still returns status 1 for four pre-existing
`inherit`-style warnings at lines 237, 242, 246 and 270; JSON diagnostics were
compared with `git show HEAD:flake.nix` and are identical. They were not hidden
or repaired by unrelated edits. Initial development runs corrected a store-context
regex in the new evaluation test, Home Manager's evaluated `.data` nesting,
OpenSSH output case/stderr capture in the VM oracle, and lint/formatter issues;
these were fixture/evaluation fixes, not weakened security assertions. The first
expanded lifecycle VM run timed out because the fixture inherited shell
`errexit` and failed to write its status after the expected injected reload
failure. It was not counted as passing. Explicit conditional status capture and
bounded waits fixed the fixture; the final expanded run passed all ten subtests
in 590.10 seconds (`asawn6qsa4sa8hy7vrcnrcyznksq0zzr-vm-test-run-ssh-lan-tailscale`).

The following check remains **BLOCKED**, not passed:

```sh
nix eval --impure --raw --file /tmp/dancer-phase-b-local.nix checks.x86_64-linux.host-invariants.drvPath
```

It exits 1 because
`.superpowers/sdd/2026-10-02-multi-host-dancer/kellanved-baseline.json` is absent.
No baseline was fabricated and no assertions removed. No unrestricted
`nix flake check`, whole-tree pre-commit check, or `deploy-activate` was run.

## Local source-copy incident

Before the wrapper correction, the agent incorrectly used plain-path
`builtins.getFlake`, which copied nine whole worktrees, including `.git` and
untracked extras, into the local Nix store. Eight contained the user's policy
backup. The agent stopped, disclosed the mistake, and obtained approval for
metadata/reference investigation and then targeted cleanup. Private snapshot
contents were not inspected. A GC-root query unexpectedly removed stale root
symlinks, not their targets; this side effect was disclosed.

All nine current-session snapshots were deleted using explicit paths with
`nix store delete --offline`, normal liveness protections, no recursive/global
GC, no `--ignore-liveness`, and no sudo escalation. Their absence was verified.
The inventory then showed zero current-session whole-worktree snapshots and
zero store-root policy-backup copies. Twenty-five older whole-worktree copies
were left untouched for separate review. Deletion does not prove secure erasure
from filesystem snapshots/backups. The corrected wrapper's Git-filtered source
was verified not to contain `.git` or the untracked extras. No store upload or
production deployment was performed by the agent.

## Remaining admin and live acceptance work

The restrictive policy was saved by the owner, but policy-editor tests using
actual enrolled devices are still pending. The actual Dancer MagicDNS hostname
has not been learned; the shared LAN alias remains unchanged and unactivated.

The approved lifecycle correction and transition checks are complete locally.
Separately approve a reviewed, published immutable source and live maintenance,
and follow the handoff in order: trusted LAN plus local-console recovery;
first-enrollment/state recheck; healthy firewall/sshd/preference services;
private persistent mount and forwarding checks; fresh LAN SSH; only then the
explicit safe tagged server enrollment and user-owned client enrollment.
Kellanved activation needs its own approval too. Do not enroll Dancer merely
because local checks passed or the policy was saved.

All live acceptance items are **NOT RUN by the agent**: tagged-device/account
verification, policy allow/deny tests, fresh overlay SSH, hotspot-only access,
IPv4/IPv6 live coverage, real daemon/firewall restarts in both orders, server-side
Tailscale shutdown with LAN fallback, and separately approved attended reboot
with stable node identity/state. No unapproved second identity is invented to
claim denial coverage. Dancer still requires a physically attended LUKS unlock.
