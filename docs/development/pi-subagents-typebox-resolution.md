# Pi subagents: TypeBox resolution failure and validated workaround

Date: 2026-11-12.

**Status:** Node-mode override applied, built, and activated by the operator on
`kellanved` (x86_64 Linux). Native foreground structured-output smoke tests passed
on Pi 1.5.0 and the subsequently installed Pi 1.5.2. After a full Pi restart, the
working session was confirmed to run under Node with no stale `PI_PACKAGE_DIR`.
Detached background execution and other platforms have not been validated.

## Issue

A `pi-subagents` child completed a code review but could not submit its required
native `structured_output` result. The workflow therefore failed, rather than
accepting the review or launching its dependent measurement task:

```text
Structured output invocation was rejected: validator unavailable.
Cannot find package 'typebox' ...
PI_SUBAGENTS_PI_CODING_AGENT_PACKAGE_ROOT is not set
Required structured output was not produced
```

This is a local JavaScript module-resolution problem, not an API-key, credential,
network-access, or Python dependency problem. Ordinary subagent work and saved
prose reports succeeded; native structured-output validation failed.

The observed installation was Pi **1.5.0** and `pi-subagents` **0.88.0**. The
extension is configured as the unversioned `npm:pi-subagents` package and has a
daily update timer, so its installed version can change independently of the
locked Pi package.

## Confirmed packaging and resolver behavior

This repository selects Pi in:

```text
/home/roberto/phlake-shack/homes/profiles/pi-coding-agent/default.nix
```

Before the workaround, the selection was:

```nix
package = pkgs.llm-agents.pi;
```

`flake.nix` exposes the upstream flake's packages as `pkgs.llm-agents`, retaining
upstream's own nixpkgs pin. At diagnosis and native smoke-test time, `flake.lock`
pinned `llm-agents` to `499fb79f92064e92cdb968d12ffeb92d36243b50`; that revision
packages Pi 1.5.0.

The **locked revision**, not just current upstream HEAD, supports `useBun ? true`:

- [Pinned Pi package definition](https://github.com/numtide/llm-agents.nix/blob/499fb79f92064e92cdb968d12ffeb92d36243b50/packages/pi/package.nix)
- [Pinned version and dependency hashes](https://github.com/numtide/llm-agents.nix/blob/499fb79f92064e92cdb968d12ffeb92d36243b50/packages/pi/hashes.json)

With the default `useBun = true`, the package compiles a standalone binary, removes
its normal npm installation tree, and assembles a release layout under
`$out/libexec/pi`. It sets `PI_PACKAGE_DIR` to that directory. TypeBox is a declared
host dependency (1.3.27), but there is no physical `node_modules/typebox` tree in
that installed layout.

The installed extension's resolver is in:

```text
/home/roberto/.pi/agent/npm/node_modules/pi-subagents/src/runs/shared/structured-output.js
```

It first attempts a lazy native import of `typebox/compile`. Its fallback uses
`createRequire(<Pi package root>/package.json).resolve("typebox/compile")`, trying
an explicit package-root environment variable and discovered Pi roots. The source
itself notes that this lazy import can miss Pi's host-package aliases.

In the failing installation:

```text
PI_PACKAGE_DIR=/nix/store/3hvs5jdghcb70i8sf8q19sxp5d5fs4sc-pi-1.5.0/libexec/pi
PI_SUBAGENTS_PI_CODING_AGENT_PACKAGE_ROOT=<unset>
```

A read-only Node probe against that exact package root also returned:

```text
MODULE_NOT_FOUND: Cannot find module 'typebox/compile'
```

Thus, merely setting the missing environment variable to the existing standalone
package root would not supply the module tree the fallback expects. The evidence
points to a compatibility mismatch between the standalone layout and this
extension's lazy resolver; it does not establish that all Pi extensions or all
Bun installations are broken.

## Applied minimal workaround

Use the **existing Node mode of the same locked Pi package**. In
`homes/profiles/pi-coding-agent/default.nix`, only the package selection changed:

```diff
-    package = pkgs.llm-agents.pi;
+    package = pkgs.llm-agents.pi.override {
+      useBun = false;
+    };
```

The Node branch retains the normal `buildNpmPackage` installation and dependency
tree instead of replacing it with the standalone release layout. The build and
native foreground smoke test confirmed that the host TypeBox installation is resolvable
by the extension's fallback on the tested host.

Keep the following unchanged:

- `flake.lock`, the llm-agents input, and its upstream nixpkgs pin;
- the existing Pi extension list and `extraPackages`, including Node and Bun;
- diagCCMC source, Python environment, dependencies, inputs, and measurement data;
- all scientific and measurement acceptance gates.

Do not run a global `npm install typebox` or add TypeBox to diagCCMC. Pi's package
documentation treats TypeBox as a host-provided peer dependency and warns against
bundling duplicate host packages in extensions. An upstream resolver fix that
works with standalone Pi is another possible long-term solution, but it is not
implemented or validated here.

## Validation and rollout procedure

1. Build the overridden Pi package before activation, without updating the lock.
   The override changes its derivation/store path and may require a local build
   rather than the cached default Bun output.
2. Confirm Pi matches the version selected by the lockfile (originally 1.5.0),
   identify its actual Node package root, and verify that `typebox/compile`
   resolves there and exports `Compile`.
3. Start a fresh Pi process using the built Node variant. An existing process
   continues using its old executable and loaded extensions. Use an isolated
   test session, not an in-place replacement of an active workflow.
4. Run one tiny subagent with native `outputSchema`/`structured_output`, returning
   a trivial object such as `{"ok":true}`. Require successful validation, a
   persisted structured result, and successful workflow completion. A plain
   Markdown/JSON-looking response is not proof that the native validator works.
5. Only after that passes, activate through the usual host-specific NixOS or
   Home Manager workflow and reopen the working session. This profile is shared;
   validate each intended platform before broad rollout.

If resolution or the smoke test still fails, preserve the failure and investigate
host-root discovery or the extension integration. Do not weaken schema validation
or silently switch execution mechanisms.

Rollback is to restore `package = pkgs.llm-agents.pi;` and reactivate the previous
configuration/generation. No lockfile update is required for this proposal.

## Validation results (2026-11-12)

Built the package selected by the actual `kellanved` Home Manager configuration,
without activation or a lockfile update:

```sh
nix build --no-update-lock-file --no-link --print-out-paths \
  '.#nixosConfigurations.kellanved.config.home-manager.users.roberto.programs.pi-coding-agent.package'
```

- Built output: `/nix/store/72av35iilfhgki7hv8bi11k1xiap4cfr-pi-1.5.0`.
- `bin/pi --version` returned `1.5.0`; the extension remained `0.88.0`.
- The actual Node package root is under that output at
  `lib/node_modules/@earendil-works/pi-coding-agent`.
- `createRequire` from that root resolved `typebox/compile` to
  `node_modules/typebox/build/compile/index.mjs`, exporting `Compile`.
- A direct probe of the installed extension's validator helpers, with the Node
  CLI entry as the host-discovery entry, accepted `{"ok":true}` and rejected four
  invalid values: a string instead of a boolean, `false` against `const: true`,
  a missing required property, and an extra property. Both argument preparation
  and final-value validation rejected those values.
- A fresh Node-mode Pi process ran an isolated, foreground `scout` child with
  native `outputSchema` and `structured_output`. The child called only
  `structured_output`, its tool result reported `Structured output captured.`,
  the persisted native result and named output both contained `{"ok":true}`, and
  the workflow completed successfully. Child run ID:
  `06f5407b-f79a-457c-ae45-635809c5dd35`.
- Tests explicitly unset inherited `PI_PACKAGE_DIR`,
  `PI_SUBAGENTS_PI_CODING_AGENT_PACKAGE_ROOT`, and (for the fresh Pi process)
  `PI_SUBAGENT_PI_BINARY`; no package-root override was needed.
- The first smoke request incorrectly supplied both `workflow` and
  `options.script` and was rejected before any child launched. One corrected
  retry using only `options.script` passed through the same native mechanism.
- `git diff --check` passed. `flake.lock` retained SHA-256
  `59ab4295357413a48af146a47f0db04e271fd78fee9d68210f47a7636c3b3a8c`.

Retained test evidence (outside the repository):

```text
/home/roberto/.local/state/pi-typebox-smoke-srhrv6Up/
  validator-probe.json
  validation-summary.json
  events.jsonl
  retry-events.jsonl
  retry-parent.jsonl
  subagent-artifacts/
```

No activation, global npm installation, extension-list change, dependency change,
or measurement work was performed. The smoke used a trivial synthetic schema;
its lightweight acceptance setting did not change any scientific acceptance gate.
The successful native smoke covers foreground execution only, not detached
background children or another platform. Activation remains a separate rollout
step, followed by reopening Pi in a clean launch environment.

## System-build follow-up after lockfile update

A later rebuild used an already-modified `flake.lock`, with `llm-agents` updated
to `a4ef5bdd670dc14d115a2f4cd38a2955303254f3` and Pi 1.5.2. The failed
build log identified an unrelated Helix dependency, Gersemi 0.29.2:

```text
ld.bfd: cannot find -lsqlite3: No such file or directory
could not compile `gersemi-rust-backend`
```

`homes/profiles/helix/default.nix` now adds `pkgsUnstable.sqlite` to that package's
build inputs and `pkgsUnstable.pkg-config` to its native build inputs using
`overridePythonAttrs`. The existing lockfile changes were left intact.

The full `kellanved` system was then built with `--no-update-lock-file --no-link`,
producing:

```text
/nix/store/3c0qd9ayhsv80fr559j686qvk7sicjxg-nixos-system-kellanved-26.05.20261108.ac588ef
```

Gersemi's version and a small CMake formatting smoke test passed, as did Nix
formatting and whitespace checks. The selected Node-mode Pi reports 1.5.2, but
the native subagent smoke had not yet been repeated at that stage. No system
activation or measurement work was performed by the assistant.

## Post-activation verification on Pi 1.5.2

After the operator rebuilt and activated the system, the installed command
pointed to Node-mode Pi 1.5.2. Reloading extensions alone left the existing
conversation running under the old Pi 1.5.0 standalone executable and carrying
its old `PI_PACKAGE_DIR`. A full exit and restart resolved that stale process:
`pi --version` reported 1.5.2, the session's executable was Node, and
`PI_PACKAGE_DIR` was unset.

A fresh process launched through the activated user-profile command passed the
native foreground smoke on Pi 1.5.2 with `pi-subagents` 0.88.0. The child called
only `structured_output`, both persisted outputs contained `{"ok":true}`, and
the workflow completed. Run ID: `48301491-4d2e-44c7-82e9-40bcdfec9ef7`.
The extension's validator also accepted valid data and rejected all four invalid
cases described above. The initial request was rejected before child execution
because `acceptance.level: "none"` lacked a required reason; one corrected retry
passed through the same native mechanism.

Evidence is retained at:

```text
/home/roberto/.local/state/pi-typebox-post-activation-GZcmUpnF/validation-summary.json
```

Detached background execution remains untested. No measurement work was resumed.

## Relation to the paused diagCCMC work

No real-input death-kernel or propagation job was launched by the stopped
measurement workflows. The latest tooling review also contains **two blockers
and two important validation/cleanup findings**. Repairing this harness issue does
not resolve those findings or authorize measurements. Resume only the unfinished
code-fix/review work, preserving completed work and all existing budgets/gates.

The campaign checkpoint and retained review are:

```text
/home/roberto/.local/state/diagccmc/measurements/issue-115/stage-a-20261110T185336Z.TXmWlC/stage-e/death-diagnostic-1/parent-runtime-stop.md
/home/roberto/.local/state/diagccmc/measurements/issue-115/stage-a-20261110T185336Z.TXmWlC/stage-e/death-diagnostic-1/parent-retained-tooling-review-2.md
```

This note records the diagnosis, applied package override, and validation
results, including the operator's subsequent activation and restart. It does not
authorize resuming measurements.
