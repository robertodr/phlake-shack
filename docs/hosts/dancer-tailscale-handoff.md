# Implementation handoff: remote SSH to Dancer over Tailscale

## 0. Status, authority, and execution rules

**Repository-only Phase B and the explicitly approved lifecycle correction are implemented and locally tested; live work is not authorized.** The original cleanup skeleton's reload exposure was reproduced and corrected using the Dancer-only lifecycle cap specified in B2 below. See the [Phase B implementation report](dancer-tailscale-phase-b.md) for approved scope, exact checks, limitations, and the disclosed local source-copy incident and cleanup. No production Tailscale enrolment, firewall activation, deployment, or reboot has been performed by the implementing agent. The remaining phases below retain their separate approval and acceptance gates.

The implementing agent must obtain approval for repository implementation before changing configuration or tests. Approval to edit/build does **not** authorize deployment, account changes, enrolment, or reboot. Obtain separate approval for live maintenance; the user must handle identity-provider authentication, MFA/passkeys, and admin-console actions. Reboots require additional approval and someone physically present with Dancer's LUKS passphrase.

Execution rules:

1. Follow the phases below in order. Do not enrol Dancer before the restrictive tailnet policy is saved.
2. Stop at a failed check or unmet prerequisite. Report the problem; do not weaken security to continue.
3. Do not put credentials, auth URLs, Tailscale state, private keys, or passwords in Git, the Nix store, command arguments, or reports.
4. Do not change `flake.lock`, unrelated host configuration, storage, boot policy, or deployment targets to make this task easier.
5. Keep a trusted LAN SSH connection and local-console recovery available during live maintenance. Do not rely solely on an already-established SSH session: test fresh connections too.
6. If making a commit, use the installed GitButler skill and a conventional commit with `Assisted-by: <harness>:<model>`.

## 1. Settled design — do not substitute another architecture

Use **ordinary OpenSSH over Tailscale**, not Tailscale SSH:

```text
Travelling computer -> encrypted Tailscale network -> Dancer TCP 22
                    -> OpenSSH public-key authentication as roberto
```

Two independent controls must both pass:

- Tailnet policy: only the approved user's user-owned devices may initiate TCP 22 connections to `tag:dancer`.
- Dancer host firewall: only TCP 22 is exposed to new inbound TCP/UDP connections through `tailscale0`, regardless of broader tailnet permissions. Existing home-subnet IPv4 SSH remains available. Preserve the normal established/related and ICMP handling described below.

**Dancer's NixOS firewall will be the sole owner of its kernel packet-filter rules. Set Tailscale's netfilter mode to `off`.** This is a deliberate manual-firewall integration for a non-routing endpoint, not a generic Tailscale installation recipe. It requires the UDP opening, interface filtering, source-spoofing protection, and forwarding restrictions specified below. Tailscale's userspace enforcement of tailnet grants remains enabled.

Why this decision matters: plain `tailscale up` defaults to netfilter mode `on`. The inspected Tailscale source inserts an `INPUT -> ts-input` jump and accepts traffic arriving on `tailscale0`. That can bypass `nixos-fw` and expose non-SSH services at the host-firewall layer. Merely avoiding `trustedInterfaces` or moving rules inside `nixos-fw` is insufficient.

Do not replace `off` with `on` or `nodivert`, add manual hooks to `ts-*` chains, or leave rule ordering as an implementation-time choice. No Tailscale-owned chains are needed in this design. If a future requirement needs routing or Tailscale-managed hooks, stop and obtain a new design review.

Out of scope:

- Public TCP 22, router port forwarding, public DNS, static public IPs.
- Tailscale SSH, exit nodes, subnet routing, app connectors, Serve, or Funnel.
- Broad trust of `tailscale0`, new SSH authentication methods, or remote LUKS unlock.
- Tightening unrelated clients' existing inbound-firewall policies.

## 2. Repository facts and files to read first

Re-read these files in the current checkout before editing:

| File | Relevant current behavior |
| --- | --- |
| `systems/x86_64-linux/dancer/default.nix` | Imports `../../profiles/services/openssh/lan-only.nix` and impermanence; attended LUKS; suspend/hibernate disabled. |
| `systems/profiles/services/openssh/lan-only.nix` | OpenSSH enabled; `openFirewall = false`; root/password/keyboard-interactive login disabled; existing Ed25519 key labelled `kellanved`; nftables forced off; explicit iptables/ip6tables SSH rejection, with IPv4 exception for `192.168.68.0/22`. |
| `systems/profiles/impermanence/default.nix` | Root rollback; `/persist` bind mounts; SSH host keys persisted; no `/var/lib/tailscale` entry yet. |
| `systems/x86_64-linux/kellanved/default.nix` | Separate client host and additional persistence entries. Do not import Dancer's server-only modules here. |
| `homes/profiles/ssh/default.nix` and `ssh_config` | Shared SSH configuration; current `dancer` alias points to `192.168.68.104`; connection multiplexing enabled. |
| `flake.nix` | Host/module wiring, check registration, and deploy-rs. Deployment explicitly targets Dancer's LAN IP. |
| `tests/ssh-lan.nix` | Existing LAN/outsider IPv4 and IPv6, authentication, Docker interaction, and firewall-restart tests. |
| `systems/profiles/services/openssh/dancer-firewall-lifecycle.nix` and `dancer-firewall-lifecycle.py` | Approved Dancer-only command ordering, lifecycle recovery cap and native-rule validation; required by the LAN-plus-Tailscale profile. |
| `tests/ssh-lan-unrestricted-red.nix` | Deliberately failing negative fixture; do not register it as a normal passing check. |
| `tests/host-invariants.nix`, `tests/host-snapshot.nix` | Existing account/firewall and preserved-Kellanved assertions. |
| `tests/dancer-manual-boot-eval.nix`, `tests/impermanence.nix` | Boot, persistence, and root-rollback checks. |
| `docs/hosts/dancer-deploy-rs.md` | Required source/precheck/deployment workflow and separate live-maintenance boundary. |

Inspect the **pinned**, not online-latest, Nixpkgs Tailscale and iptables-firewall modules. At plan revision time:

- The pinned Tailscale package is `1.104.5`; verify again without updating inputs.
- `services.tailscale.extraSetFlags` creates a `tailscaled-set.service` that runs `tailscale set`.
- `extraUpFlags` is used only with `authKeyFile`; it does not configure this interactive-enrolment design.
- `openFirewall` adds the Tailscale UDP port, not TCP 22.
- Firewall `extraCommands` runs before the final refuse rule; explicit `-I ... 1` rules precede generated allowed-port and connection-tracking rules.

`host-invariants` currently depends on the absent private file `.superpowers/sdd/2026-10-02-multi-host-dancer/kellanved-baseline.json`. Do not fabricate that baseline, delete assertions, or claim the check passed. Add a standalone Tailscale evaluation check without that dependency and report this existing blocker separately. Follow the deployment runbook's targeted checks rather than running unrestricted `nix flake check` on Framework.

Plan-author validation: the Nix and shell examples below were syntax-checked, and the policy example parsed as JSON. The two proposed modules were also evaluated as temporary additions to the current Dancer configuration: the required service flags, UDP opening, restrictive persistence permissions, disabled forwarding, retained LAN rules, and absence of global TCP 22/interface trust evaluated as intended. This was configuration-only evaluation, not a repository implementation, VM packet test, activation, or live test. The implementing agent must still create the files and run the checks below.

## 3. Phase A — guide account/tailnet setup and resolve prerequisites

### A1. Walk the user through their new account

The user has just created a Tailscale account and needs interactive instructions, not merely a list of prerequisites. Do not assume they understand the admin console, tailnets, tags, or grants. Give one small group of actions at a time, explain the expected result, and wait for confirmation before proceeding. The user performs authentication and console changes themselves; do not request passwords, MFA codes, auth URLs, browser sessions, or API/auth keys.

A **tailnet** is the private network associated with the account/organization. Tailscale creates it during signup/initial login; there normally is not a separate server to provision or a second network-creation procedure. Verify what exists rather than telling the user to create another account or tailnet.

Guide the user through these steps:

1. Open <https://console.tailscale.com/admin> and sign in with the same identity provider used for the new account. Complete any basic personal-use onboarding prompts. If multiple tailnets are available, confirm the selected one is their intended personal tailnet, not an employer's or another organization's network.
2. Confirm they can see the admin console and have permission to manage access controls. On **Users** (<https://console.tailscale.com/admin/users>), identify their exact Tailscale login identity for the eventual policy. Do not infer it from a local Unix username or an email they have not verified in the console.
3. On **DNS** (<https://console.tailscale.com/admin/dns>), explain where to find the tailnet DNS suffix and check MagicDNS. Do not rename the tailnet just to match an example. Dancer's full device hostname is not known until it is enrolled.
4. Locate **Access controls** (<https://console.tailscale.com/admin/acls>) and its JSON policy editor. Explain that the initial broad allow rule is not the final policy. Inspect it without changing it yet; Phase C supplies the exact reviewed tag/grant configuration and requires explicit user confirmation before saving.
5. Confirm MFA/passkeys protect the identity-provider account and check that the selected subscription is suitable for personal use. Do not activate paid features or rely on unverified free-tier limits.

If the console shows only an **add your first device** onboarding screen, first try the direct Access controls link above. Do not invent a skip button or tell the user to enrol Dancer to get past onboarding. Ask what screen they see if the instructions do not match; any shared screenshot must omit authentication links/codes and other secrets.

If policy access genuinely requires enrolling a first device, stop and explain the dependency. With separate, explicit user approval, guide them through enrolling **only the intended travelling client**, user-owned, into the otherwise new/empty personal tailnet. This is the sole early-client bootstrap exception; use the client's supported installation workflow and obtain any needed client-activation approval. Do not tag it as Dancer, enrol the server, create auth keys, or enable routing. Then return to the admin console and complete policy preparation before Dancer ever joins. If the tailnet is not actually empty or the user does not approve client bootstrap, stop for review instead of assuming the default broad policy is safe.

Record whether the tailnet already existed and whether a client was bootstrapped; do not reset or enrol that client a second time later.

### A2. Resolve implementation prerequisites

Record the answers in the implementation report, not as guessed configuration:

- Which travelling device(s) will be used? Is Kellanved one of them? What operating systems do they run?
- Can each intended client already authenticate to `roberto@192.168.68.104` with an approved SSH key? Dancer currently authorizes the key labelled `kellanved` only. If another client needs a key, ask approval to add its **public** key; never copy private keys or enable password login.
- Which exact Tailscale account identity owns the client? Use the actual policy-editor identity, not an inferred email address.
- Is this a new or existing tailnet? Does the user authorize reviewing/changing its policy? Preserve unrelated access only when explicitly intended.
- Does the user accept that the source identity selects **all user-owned devices of that account**, not just one laptop? If not, stop and review a device-specific source policy.
- Has Dancer already been enrolled or acquired Tailscale state since this plan was written? This plan assumes first enrolment. If state already exists, stop for an explicit migration plan; starting an enrolled daemon with old `on` preferences could expose services before a later `tailscale set` runs.

The account has already been created; help the user complete or verify its setup rather than repeating signup. Verify current Personal-plan terms if necessary; do not rely on unverified numerical free-tier limits.

**Exit condition:** the user can access the intended personal tailnet and policy editor; client/key prerequisites and the intended identity and scope are known. No Dancer enrolment has occurred. Client enrolment is still deferred unless the user explicitly approved the A1 bootstrap exception.

## 4. Phase B — implement and test repository changes, without activation

### B1. Add a Dancer-only service/persistence module

Create `systems/profiles/services/tailscale/dancer-ssh.nix` with this intended configuration, adjusting only if the pinned module requires a reviewed correction:

```nix
{ ... }:
{
  services.tailscale = {
    enable = true;
    interfaceName = "tailscale0";
    port = 41641;
    openFirewall = true;
    useRoutingFeatures = "none";
    authKeyFile = null;
    extraSetFlags = [
      "--netfilter-mode=off"
      "--ssh=false"
      "--accept-routes=false"
      "--advertise-exit-node=false"
      "--advertise-routes="
      "--exit-node="
    ];
  };

  # This profile is an endpoint, never a router.
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 0;
    "net.ipv6.conf.all.forwarding" = 0;
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/tailscale";
      user = "root";
      group = "root";
      mode = "0700";
    }
  ];
}
```

Do not put these CLI preferences in `extraDaemonFlags` or rely on `extraUpFlags`. Persisted preferences and the explicit first-enrolment command must agree; `extraSetFlags` is not a pre-start migration mechanism for an already-enrolled node.

Add `../../profiles/services/tailscale/dancer-ssh.nix` to the existing `imports` list in `systems/x86_64-linux/dancer/default.nix`; keep all unrelated imports. Do not enable it globally or import it into Kellanved. Preserve the existing SSH host-key persistence and other persistent paths. Do not change root rollback, boot masks, disk layout, or SSH authentication settings.

For an approved NixOS travelling client, add a **separate client-only** service/persistence configuration. Do not reuse Dancer's routing restrictions, server firewall module, or server tag. For other operating systems, use their supported Tailscale client. Client installation/configuration is subject to the user's approved scope. Dancer's manual-netfilter decision does not prescribe a new firewall architecture for those clients.

### B2. Add a LAN-plus-Tailscale SSH firewall profile

Create `systems/profiles/services/openssh/lan-and-tailscale.nix`. Import `./lan-only.nix` so the existing authentication and LAN rules remain unchanged, and append the new commands using `lib.mkAfter`. In Dancer's existing imports list, replace only `../../profiles/services/openssh/lan-only.nix` with `../../profiles/services/openssh/lan-and-tailscale.nix`; do not modify other hosts' imports.

Use a NixOS-owned chain named `dancer-ts-input` in **both** iptables and ip6tables. Do not edit Tailscale's `ts-input` chain. The following is the intended implementation skeleton:

```nix
{ lib, ... }:
{
  imports = [
    ./lan-only.nix
    ./dancer-firewall-lifecycle.nix
  ];

  networking.firewall = {
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

    extraStopCommands = lib.mkAfter ''
      for tool in iptables ip6tables; do
        "$tool" -w -D nixos-fw -j dancer-ts-input 2>/dev/null || true
        "$tool" -w -F dancer-ts-input 2>/dev/null || true
        "$tool" -w -X dancer-ts-input 2>/dev/null || true
      done
    '';
  };
}
```

Required semantics, in order:

1. The first rule in each `nixos-fw` chain jumps to `dancer-ts-input`, before the original SSH rejection and any generic port allowances.
2. Loopback returns to the existing NixOS rules; it is exempt from the source-spoofing checks, not newly blanket-trusted by this module.
3. TCP 22 on `tailscale0` is accepted before the original LAN-only rejection, for IPv4 and IPv6.
4. Other established/related traffic and ICMP from `tailscale0` return to the normal NixOS policy. Returning is not an unconditional accept.
5. All remaining traffic from `tailscale0` is dropped. In particular, globally allowed TCP/UDP service ports must not become exposed through that interface.
6. Traffic claiming a Tailscale source address on other interfaces is dropped. The preceding loopback and `tailscale0` handling preserves legitimate local/tailnet traffic. No CGNAT exception for another overlay is approved; stop if such a conflict is discovered.
7. Other traffic returns to the existing firewall: IPv4 SSH from `192.168.68.0/22` remains allowed, and other IPv4/IPv6 SSH remains rejected.

The chain's lifecycle must be safe across start/reload/restart: create if absent, flush/repopulate its own rules, attach exactly once, and remove its own references before deleting it on stop. Do not flush built-in chains or unrelated software's chains. Do not suppress errors when installing security rules; the best-effort cleanup above is only for possibly absent owned rules/chains. Test the skeleton against the pinned firewall implementation rather than assuming it is production-validated.

Keep nftables disabled on Dancer, `services.openssh.openFirewall = false`, all existing authentication restrictions, and the approved authorized keys. Do not add TCP 22 to global allowed ports or add `tailscale0` to `trustedInterfaces`. Do not disable reverse-path filtering to make a test pass; fix test routing instead.

### B2a. Approved lifecycle correction — required with the skeleton above

The original skeleton alone is unsafe during the pinned reload: NixOS appends
`INPUT -> nixos-drop` after the existing main hook, then cleanup removes the
steady guard before the old main hook is detached. The user explicitly approved
this correction after the defect was explained; it is not an unreviewed switch
to a different Tailscale/netfilter architecture.

The Dancer-only helper module and Python implementation named above install an
independent `dancer-fw-hold` cap first in both INPUT chains before native start,
reload or stop. They preserve the native scripts through ordered systemd command
lists. Start/reload releases the cap only after verifying both families' full
evaluated native/steady filter chains, rpfilter and disabled forwarding. Stop or
failure deliberately leaves the cap installed. No attached cap is flushed or
rewritten; unexpected contents, hooks or ordering stop the operation.

The cap preserves approved LAN/Tailscale SSH, established/related replies, normal
IPv4/IPv6 ICMP handling and physical UDP 41641. Other physical services may be
briefly blocked, never newly exposed. It retains source-spoofing protection and
drops other Tailscale ingress. It does not reference native chains that the
backend deletes, touch Tailscale-owned chains, or change Kellanved's firewall.
Only detached owned chains may be flushed; reference/order counts must remain
exact. Do not flush a retained cap as a recovery shortcut. Older generations
without this helper may leave it installed on rollback; preserve trusted LAN
SSH and local-console recovery and obtain review before changing those rules.

VM checks must pause operations after native cleanup and exercise ingress during
reload/restart, injected failure, and stopped states. They must prove the old
unguarded cleanup exposes canaries, installation is idempotent without resetting
counters, and an IPv6 validation failure retains BOTH caps. See the report for
passing results and limits; none constitutes enrolled-daemon live acceptance.

### B3. Add explicit evaluation and VM checks

Create `tests/tailscale-ssh-eval.nix` and `tests/ssh-lan-tailscale.nix`, and register them as `checks.x86_64-linux.tailscale-ssh-eval` and `checks.x86_64-linux.ssh-lan-tailscale` in `flake.nix`. Expose `.report` on the evaluation check for the commands below. Keep the existing `ssh-lan` test for the unchanged LAN-only profile. Do not replace its assertions with weaker ones or register the deliberately failing red fixture as a normal check. Update old LAN-only descriptions to reflect Dancer's new policy. If an additional SSH public key was explicitly approved, update the existing exact-key-list invariant to that approved list rather than deleting the invariant.

The evaluation check must not depend on the private Kellanved baseline. Assert:

- Dancer imports/enables the intended service and firewall policy, with interface `tailscale0`, UDP 41641 open, and exactly one root-owned `0700` persistent state directory.
- `authKeyFile` is null; all required `extraSetFlags` are present; generated `tailscaled-set` actually invokes those flags. No automatic auth-key enrolment is configured.
- Tailscale SSH/routing/exit-node settings are disabled as specified, and kernel forwarding is disabled.
- OpenSSH authentication and authorized keys remain as approved; no global TCP 22 opening or blanket interface trust exists.
- The original LAN rules and the new guard are both present in the generated firewall commands; lifecycle install/release commands surround, rather than replace, the native unit commands in the approved order.
- Unapproved hosts are unchanged. If Kellanved is an approved client, assert the separately approved client settings instead of expecting it to remain disabled.
- Dancer's deploy-rs node still uses `192.168.68.104`, existing rollback settings, and no agent forwarding.

The VM check must exercise actual packet ingress, not just inspect strings:

| Case | Expected result |
| --- | --- |
| IPv4 SSH from the existing home `/22`, including `192.168.69.x` | Success with the test key |
| SSH from the simulated Tailscale link, IPv4 and IPv6 | Success with the test key |
| SSH from non-LAN physical IPv4 and physical IPv6 | Rejected |
| Root, password, or keyboard-interactive SSH login | Denied |
| New TCP and UDP connections to a non-SSH test service through the Tailscale link | Blocked |
| Tailscale-source addresses spoofed through a physical link, IPv4 and IPv6 | Blocked |
| Reply traffic for a permitted connection initiated by the server | Works; not accidentally blocked by the guard |

Test-fixture instructions:

1. Import the production LAN-plus-Tailscale firewall profile. Use a second VM network/link actually named `tailscale0` for simulated tailnet ingress; use separate physical-link addresses for LAN and outsider traffic. A dummy interface with no incoming packets is not a sufficient test.
2. Disable the real `tailscaled` in this packet-test fixture only, to avoid it trying to create its own TUN named `tailscale0`. Explain this override in the test. Do not use production credentials.
3. Bind controlled non-SSH TCP and UDP services, for example on port 8080. Open these ports **in the VM fixture only** through the normal global allowed-port settings. Prove the listeners work from a permitted physical test path, then prove the Tailscale link cannot reach them. For UDP, use a request/reply or packet-capture assertion; `nc -z -u` alone is not reliable proof of blocking.
4. For spoofing tests, arrange valid physical return routes so reverse-path filtering does not mask a missing guard. Example source networks: `100.105.0.0/24` and `fd7a:115c:a1e0:2::/64` on the physical test link, distinct from the simulated tailnet link.
5. Include representative detached Tailscale-managed `ts-input` chains that accept `tailscale0` traffic, in both address families. Assert there is **no** active `INPUT -> ts-input` jump and no earlier equivalent accept that bypasses `nixos-fw`. Check the first guard jump, ordering, and duplicate/reference counts.
6. Prove the test detects the original failure: in an isolated negative-control subtest, temporarily insert an unsafe `INPUT -> ts-input` jump ahead of `nixos-fw`. The rule checker and non-SSH denial probe must detect the regression; the controlled listener should now be reachable. Remove the hook and rerun the passing assertions. Keep this expected-failure subtest inside an otherwise passing check, not as a permanently failing registered check.
7. Repeat the positive/negative traffic matrix and chain checks after firewall reload, firewall restart, and recreation of the detached simulated Tailscale chains. Ensure rules do not accumulate and unrelated chains are preserved.
8. Do not call this proof of real enrolled-daemon restart behavior, tailnet policy, or persistence. Those require the live acceptance steps below. A separate real-daemon integration test is welcome if it uses only isolated local test infrastructure, not production enrolment.

Add a synthetic persistence-marker assertion to an appropriate impermanence test if practical: the configured bind mount must preserve the marker through root rollback, with the expected permissions. Even with that test, real node-identity persistence remains a live acceptance requirement.

### B4. Run targeted prechecks and report before live work

For the current approved source, run the new evaluation and VM checks plus relevant existing checks. For example, after registering the named outputs:

```sh
nix eval --json .#checks.x86_64-linux.tailscale-ssh-eval.report
nix build --no-link \
  .#checks.x86_64-linux.tailscale-ssh-eval \
  .#checks.x86_64-linux.ssh-lan-tailscale \
  .#checks.x86_64-linux.ssh-lan
```

Also use the targeted deploy/schema/manual-boot prechecks in `docs/hosts/dancer-deploy-rs.md`, format/lint the changed Nix files, and run relevant persistence checks where supported. Stage new files through the approved GitButler workflow if needed for flake visibility; do not silently build an older source that omits them.

Record each exact command, source revision, outcome, and any infrastructure/private-baseline blocker. Never describe a skipped or unevaluated VM check as passing. If evaluation succeeds but virtualization is unavailable, obtain an approved test environment before live activation rather than weakening tests.

**Exit condition:** implementation reviewed, relevant checks pass, no secrets or placeholder values in executable configuration, and live work is still awaiting approval. Illustrative placeholders in this plan are not configuration to deploy.

## 5. Phase C — user saves restrictive tailnet policy BEFORE enrolment

This phase is a guided user/admin-console action after scope approval. It must finish before Dancer is enrolled. Prefer completing it before production service activation as well. Open **Access controls** at <https://console.tailscale.com/admin/acls> and select its JSON policy editor; use current official documentation or ask what the user sees if labels differ. Explain each proposed change, show the complete policy they should save using their verified identity, and wait for confirmation that validation/save succeeded. Do not merely tell a new user to "configure ACLs" and move on.

1. Inspect the existing tailnet policy. Identify all grants/ACLs that could reach Dancer, including wildcard and broad tag/user rules. Permissions are additive: adding a narrow grant does not override an existing allow-all rule.
2. Confirm any changes to unrelated access with the user. Save the existing policy through the user's normal secure admin workflow; do not put account-sensitive exports or credentials in the repository.
3. Define `tag:dancer` and its owner **before assigning/requesting the tag**.
4. Save a policy that allows the actual user's identity to reach `tag:dancer` only on TCP 22. Remove or narrow every overlapping broad permission. Do not add temporary allow-all access to simplify onboarding.

For a dedicated single-user tailnet, the intended minimal policy is:

```json
{
  "tagOwners": {
    "tag:dancer": ["you@example.com"]
  },
  "grants": [
    {
      "src": ["you@example.com"],
      "dst": ["tag:dancer"],
      "ip": ["tcp:22"]
    }
  ]
}
```

This is an illustration, not a file to copy into Git. Replace the identity in the policy editor with the verified real identity. Do not blindly replace an existing tailnet's entire policy with this object; review intentional unrelated rules, while ensuring they cannot broaden access to Dancer. No Tailscale `ssh` policy section is needed for ordinary OpenSSH. No inbound permissions to the travelling client are needed for replies to its SSH connections.

After devices exist, add policy-editor tests for allowed user -> Dancer TCP 22 and denied user -> Dancer non-SSH ports, plus denied unapproved identities where available. Do not invent another real user just to write a test. If the editor cannot resolve a not-yet-enrolled tagged device for tests, save the restrictive permissions first and add those tests after enrolment; never postpone the restriction itself.

**Exit condition:** the user confirms the restrictive policy is saved, `tag:dancer` exists, the enrolment identity can request that tag, and overlapping broad permissions have been resolved. Without that confirmation, stop.

## 6. Phase D — separately approved LAN deployment and first enrolment

### D1. Apply the reviewed configuration over the LAN

Follow `docs/hosts/dancer-deploy-rs.md` using one reviewed, published, immutable source revision for both prechecks and deployment. Preserve its interactive sudo, signature checks, rollback protections, LAN target, and console requirements. Do not silently switch deployment to Tailscale or use a dirty/private-source export shortcut.

Before enrolment, verify on Dancer:

- `firewall.service`, `sshd.service`, `tailscaled.service`, and `tailscaled-set.service` completed/started successfully as appropriate; inspect failures rather than continuing.
- `findmnt -T /var/lib/tailscale` shows the intended persistent bind mount. Check its backing path under `/persist` too. `stat` reports root ownership and mode `0700`; state/private files are not group/world readable. Do not print their contents.
- `iptables -S INPUT`, `ip6tables -S INPUT`, and both `nixos-fw`/`dancer-ts-input` chains have the intended hooks and order; no active Tailscale-owned input hook bypasses them.
- Kernel IPv4/IPv6 forwarding is off.
- The lifecycle cap is absent after successful steady-state verification. A retained `dancer-fw-hold` means maintenance/failure protection is still active: inspect the failure, do not enroll or flush it.
- A **fresh** LAN SSH connection works with the existing approved key.

Do not enrol if the firewall, persistence, or preference-setting service is unhealthy. Do not clear state, run `--reset`, flush firewall chains, or open SSH globally to recover.

### D2. Enrol Dancer with its tag and safe preferences in the initial command

Only after Phase C and D1 pass, the user runs on **Dancer**:

```sh
sudo tailscale up \
  --netfilter-mode=off \
  --ssh=false \
  --accept-routes=false \
  --advertise-exit-node=false \
  --advertise-routes= \
  --exit-node= \
  --advertise-tags=tag:dancer
```

Use the displayed authentication flow privately, signing into the approved tailnet with the identity authorized for the tag. Do not copy the auth URL into a report. If the CLI requests other existing non-default settings, that contradicts the first-enrolment assumption: stop rather than adding `--reset` or improvising flags.

In the admin console, verify Dancer is actually tagged `tag:dancer`, not merely user-owned with a requested/unapproved tag. Review its device-key expiry deliberately. If tag assignment or enrolment fails, leave the restrictive policy in place and stop; do not fall back to an untagged, broadly reachable server.

### D3. Enrol the travelling client as a user-owned device

If the client was already enrolled through the approved A1 bootstrap exception, verify its existing account/tailnet and user-owned status; do not enrol it again, reset it, or create a duplicate registration. Otherwise, guide the user through its normal supported interactive login under the approved account. On a fresh Linux/NixOS client, ordinary `sudo tailscale up --ssh=false` is appropriate; Dancer's `off` command and server tag are **not** the client recipe. Other operating systems use their supported app/login flow. Do not tag the client as `tag:dancer`, advertise routes, or configure an exit node.

Verify both nodes in the console and inspect `tailscale status` and `tailscale ip -4` on Dancer. Do not publish full device/account inventories in reports. Recheck Dancer's effective firewall chains after enrolment: there must still be no early Tailscale-owned accept hook.

## 7. Phase E — configure SSH aliases without losing LAN recovery

The real MagicDNS name is learned after enrolment; do not guess it. Before it is known, leave the existing `dancer` alias unchanged and use an explicit verified Tailscale IP for initial tests. It is fine to complete this phase as a separately reviewed follow-up change; never commit a placeholder just to finish Phase B.

Once the user confirms MagicDNS is enabled and the client accepts its DNS configuration, update `homes/profiles/ssh/default.nix`:

```nix
{
  settings."dancer" = {
    hostname = "dancer.<actual-tailnet>.ts.net";
    user = "roberto";
    forwardAgent = false;
  };

  settings."dancer-lan" = {
    hostname = "192.168.68.104";
    user = "roberto";
    forwardAgent = false;
  };
}
```

The wrapper above illustrates the entries inside `programs.ssh`; use the actual full MagicDNS name copied from the console, not the placeholder. Apply the alias only to the intended shared/client Home Manager scope. The shared profile is used by multiple homes, so inspect their evaluated settings and ask before changing unrelated users' behavior. Apply/rebuild approved client Home Manager configuration through its normal workflow; committing an alias does not activate it.

Keep deploy-rs on the literal LAN IP `192.168.68.104`. Search for other consumers of the `dancer` alias before changing it.

A new hostname/address may prompt for host-key trust. Obtain Dancer's fingerprint through the already trusted LAN connection or local console, for example with `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`, and compare it. Do not disable host-key checking or blindly accept a changed key.

## 8. Phase F — live acceptance, while the user is still home

Record pass/fail/not-run separately for every item. Perform fresh connections with multiplexing disabled so an old SSH master cannot hide a failure. For example:

```sh
ssh -o ControlMaster=no -o ControlPath=none dancer-lan true
ssh -o ControlMaster=no -o ControlPath=none dancer 'printf "%s\n" "$SSH_CONNECTION"'
```

1. Existing LAN SSH works before and after enrolment, using the approved key.
2. SSH to the verified Tailscale IP works; after Phase E, `ssh dancer` works too. Check `$SSH_CONNECTION` and server-side connection/routing information to confirm the actual destination uses the overlay, not the LAN. Name resolution or `tailscale ping` alone is insufficient.
3. Move the travelling client to a phone hotspot and repeat a fresh SSH connection with LAN connectivity unavailable.
4. Confirm root/password/keyboard-interactive authentication remain disabled. Do not repeatedly guess real passwords; inspect effective `sshd -T` settings and use the existing automated authentication tests.
5. Run the policy-editor allow/deny tests and verify any available unapproved client cannot reach Dancer's SSH. Absence of a second identity is a limitation to report, not a passed denial test. Confirm non-SSH permissions and overlapping grants remain absent.
6. With the LAN session and console recovery available, obtain approval for relevant firewall reload/restart and **real** `tailscaled` restart tests. Repeat fresh LAN/Tailscale SSH and effective-chain checks after each operation and in both restart orders. No early `ts-input` hook may appear. Do not claim the VM's detached-chain simulation covered these real-daemon tests.
7. Check live IPv4 and IPv6 overlay SSH separately where the clients support them. Record platform limitations instead of weakening the IPv6 firewall.
8. With separate approval, disconnect/stop Tailscale on Dancer using a trusted LAN/console path and prove a fresh LAN connection still works. Restore the approved service/preferences and recheck overlay SSH. A disconnected travelling client alone does not prove the server's LAN fallback is independent.
9. Only with separate reboot approval and someone physically present, reboot Dancer, enter its LUKS passphrase locally, and confirm the same node remains enrolled/tagged, with the same Tailscale address/node identity rather than a new duplicate registration. Recheck the persistent mount, safe netfilter mode/effective chains, fresh LAN SSH, and overlay SSH. Do not reboot solely to test persistence while nobody can unlock the disk.

A non-SSH connection blocked on the live tailnet may have been stopped by grants before reaching Dancer. It is not, by itself, proof that the host firewall blocks it; that is why the independent VM packet tests and effective-chain inspection are required. Do not temporarily widen production grants just to make a firewall probe meaningful.

## 9. Operational limits, failure handling, and deliverables

- Dancer remains unavailable after reboot until someone locally unlocks LUKS. Tailscale does not solve pre-boot access.
- Review server and travelling-client device-key expiry. Tagged servers normally have different defaults; verify the actual setting. Disabled server expiry improves availability but requires deliberate revocation if compromised. Client expiry can still interrupt access while travelling.
- Revoke lost devices promptly; keep OS/Tailscale packages updated. A relayed connection is still end-to-end encrypted; direct connectivity is a performance improvement, not a requirement for SSH.
- On a failed live test, preserve the restrictive tailnet policy and the trusted LAN/console recovery path. Use the deployment runbook's approved rollback procedure. Do not disable authentication, open all ports, re-enable automatic Tailscale hooks, or remove grants restrictions as a workaround.

The implementing agent's final report must list:

1. Changed files and approved host/client scope.
2. Netfilter ownership decision, effective IPv4/IPv6 rule ordering, and persistence configuration.
3. Exact checks run, source revision, results, and skipped/blocked checks, including the private-baseline limitation.
4. User-admin steps completed versus still pending; no credentials, auth URLs, or production state dumps.
5. Live acceptance results separately from automated results, including real daemon restarts, hotspot access, LAN fallback, and attended reboot/node-identity persistence.
6. Whether the real alias was configured/activated or remains a pending follow-up.

Do not report the feature as ready for travel while enrolment, policy validation, real remote SSH, restart behavior, or required persistence verification remains untested. State the missing evidence plainly.

## References

Re-check these and the pinned sources if behavior differs; do not upgrade inputs just to match current web documentation:

- https://tailscale.com/docs/concepts/tailnet
- https://tailscale.com/docs/how-to/quickstart
- https://tailscale.com/docs/reference/visual-editor
- https://tailscale.com/docs/reference/netfilter-modes
- https://tailscale.com/docs/features/tags
- https://tailscale.com/docs/how-to/set-up-servers
- https://tailscale.com/docs/features/access-control
- https://tailscale.com/docs/reference/syntax/policy-file
- https://tailscale.com/docs/features/magicdns
- https://github.com/tailscale/tailscale/blob/v1.104.5/util/linuxfw/iptables_runner.go
- Pinned Nixpkgs: `nixos/modules/services/networking/tailscale.nix` and `firewall-iptables.nix`.
