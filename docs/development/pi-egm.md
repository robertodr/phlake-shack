# Experimental EGM integration for Pi

EGM is a document workflow, **not a model provider**. This local adapter packages
all seven upstream skills, their sibling runtime resources and nine constrained
leaf profiles. It reuses `pi-subagents`; it does not install another scheduler,
SDK, model, credential store or Claude plugin.

## Versions and trust

| Component | Audited version |
| --- | --- |
| EGM | `72d06f52a2482885d9a64bd24b291c6e8628942c`, plugin version 0.1.1 |
| Source NAR hash | `sha256-IIMahNXavG94jdYHRM8TifjEvpE0EQpAvkpTIvqOKuY=` |
| Pi | 1.5.2, Node layout (`useBun = false`) |
| pi-subagents | 0.88.1, launch contract version 3 |

The exact source hash in `pkgs/pi-egm/default.nix` is:

```text
sha256-IIMahNXavG94jdYHRM8TifjEvpE0EQpAvkpTIvqOKuY=
```

This branch is independent of the Crokus, Oleafly and skill-installation PRs
and is based directly on `main`. The separate `pi-egm-runtime` flake input pins
`numtide/llm-agents.nix` at `860075d959fc68c31fd405989daf85c1b1f0db38`
and selects only its audited Pi package for the Linux homes. Existing agent-tool
and system input pins are unchanged. The profile accepts `piEgmPackage` and uses
the Node layout; additional home targets must also provide a compatible Pi.
No Crokus target or bounded-compaction extension is added by this PR.

The source is fixed; the existing daily Pi extension updater still makes
`pi-subagents` mutable. A different Pi/subagent version fails closed until its
public APIs and effective contracts are audited and the compatibility check is
updated. Version equality does not hash-pin the mutable npm installation.

The adapter uses the documented structured foreground delegation API and public
`pi-subagents/preflight`, `capability-ceiling`, `required-child-extensions` and
`delegation` exports. RPC `ping` checks backend readiness. Public exports resolve
from the active Pi agent directory's `npm` tree, not from the Nix store or a
hardcoded home directory. The installed host's jiti forwards its **live mapped
peer exports** through public `virtualModules`; the bundled CLI's SDK is not the
adjacent unbundled SDK. Class identity is checked to refuse a second SDK instance.
No private runtime modules are imported. One version-specific internal enforcement
extension path, reported by public preflight, is explicitly audited and compared.

## Activation and commands

The Home Manager profile adds the immutable package to Pi's existing settings and
links the intact tree at `~/.pi/agent/egm`. It is Pi-only: nothing is added to the
shared `.agents/skills` allowlist or Claude's configuration. All upstream
`disable-model-invocation` declarations are retained.

The operator activates their usual NixOS/Home Manager configuration; do not run
an imperative plugin installer over these links. Restart Pi after activation or
use `/reload`, then start a fresh session if its recorded tool selection does
not include the newly installed extension. Installation/reload launches no
reviewers and does not enter EGM's design-only scope.

```text
/egm-doctor
/skill:egm-brainstorm Describe an idea to explore.
/skill:egm-draft path/to/concepts_brief.md
/skill:egm-review path/to/design.md
/skill:egm-review path/to/design.md Step=uninterrupted
/skill:egm-review-loop
/skill:egm-resolve
/skill:egm-bootstrap path/to/small-subtree
/skill:egm-drift-report docs/designs
/egm-status
/egm-exit
```

`/egm-doctor` checks host/API identity and backend readiness without a model
request. It does **not** establish reviewer isolation. `/egm-smoke disposable.md`
prepares a clearly labeled one-persona prototype, not a complete review. It
requires a separate live launch confirmation just like every review batch.

Normal provider authentication/model routing stays with Pi and pi-subagents.
Configure it through their normal controls before attempting a review. EGM
profiles may use model/provider/thinking/fast overrides, but permission, prompt,
memory, tool or extension overrides and project refinement overlays are rejected.
Enabled child watchdogs are also rejected: their additional model calls and
project guidance are not audited for Goldfish isolation. Use a deliberately
isolated configuration for probes; the adapter never changes watchdog settings
or other global subagent defaults as a workaround.

## Execution and boundaries

The existing parent is the Elephant. Upstream skill text drives clarification,
section-by-section drafting, editorial gates, synthesis and resolution in that
same context; substantive prompts are not forked into this repository. The
installed `adapter/GUIDE.md` maps each workflow to Pi tools. `egm-review` has
preset/semantic-split setup, fixed phase personas/rubrics, stage-order checks,
fresh snapshots each round and parent-written named stage/consolidated reports.
Stage 6 gets only its target document. Only Stage 8 additionally gets the initial
zoom-out report through its designated plan slot. For a standalone Stage 8 in a
new invocation, copy the approved earlier report into that invocation's artifact
slot before dispatch.

Parent workflow tools are:

- `egm_review_plan`: select/approve the upstream preset, split and reading list.
- `egm_reviewers`: dispatch a fixed phase or configured built-in review-loop group.
- `egm_save`: save drafts/synthesis/reports within the per-invocation artifact directory.
- `egm_document`: save a proposed project Markdown edit for inspection and require
  human confirmation of its exact path and proposal before applying it.

While EGM is active, parent shell/MCP/delegation and direct mutation tools are
blocked; ordinary code changes require explicitly leaving the workflow. The
single-question and zero-tool editorial human turns are upstream **model-driven
instructions**, not a formal verifier of every conversational transition. The
adapter separately enforces configuration, model-launch and document-write
approvals. A launch confirmation is not approval of the resulting findings.

Each Goldfish explicitly launches with `context: "fresh"`, no inherited project
or global instruction files, no skills, no role memory, bridge off, and only the
required scoped reader plus the audited runtime enforcement extension. The
resolved profile path/tools/extensions/context are checked before dispatch; a
successful result must match preflight's launch digest. Unexpected required
extensions, project shadowing or widened profiles stop the workflow.

Reviewers receive snapshot-backed `read`, `grep`, `find`, and `ls` only. These
implementations cannot read the live filesystem, write, execute shell/MCP/code,
or delegate. Paths resolve only to approved canonical snapshot keys; search is
literal, not regex/glob execution. Directory inputs skip hidden entries,
symlinks and dependency/build directories. No broader reading list or previous
review is preloaded into comprehension children. Per-attempt read/search audit
records accompany results; audit capacity exhaustion denies further operations.

This is a **tool/data boundary, not an OS sandbox**. Pi, trusted extensions,
provider code and the parent still run with the operator's filesystem/environment
permissions and authentication. It does not isolate credentials or defend
against arbitrary malicious code already executing in that process. Snapshot
confinement applies to model-facing reviewer tools, not the trusted host.
Parent reads are not confined by the reviewer snapshot boundary.

### Operational limits and artifacts

- Up to eight concurrent leaves; seven for the upstream brainstorm group.
- At most five rounds per phase, two attempts per reviewer, 120 attempts per invocation.
- Five minutes per leaf; 64 tool calls, then every further tool call is denied.
- At most 16 input paths, 128 text files and 1 MiB including the stage rubric.
  Oversized/binary/changed inputs fail rather than being silently truncated.
- No fork, resume, external runner, background review or nested delegation.
- Interactive UI/RPC confirmations are required. `Step=uninterrupted` suppresses
  editorial stage checkpoints, **not** operational confirmations to spend model
  quota. Fully unattended paid execution is not advertised.

Artifacts go to `<cwd>/.dev/egm/<invocation-uuid>/`, using canonical paths and
private file modes. No shared fixed scratch path or global agent settings are
modified. Raw child reports and receipts have unique identities; the parent
saves the upstream named stage reports there. Receipts record actual returned
run/model/thinking/usage/digest/status and snapshot tool reads. Missing usage is
unknown, not zero. Runtime transcripts/artifacts remain governed by pi-subagents'
normal retention; inspect them by the returned run id when collecting isolation
evidence. A completed child is execution evidence, not proof that its critique
is correct or its entire reading assignment was understood.

Failed/empty reviewers retry once in a distinct fresh child. They remain
`not run` after a second failure; the batch is partial, never clean. Cancellation
uses exact owned attempt identities. An unacknowledged cancellation or digest
mismatch stops EGM for inspection rather than launching a fallback. Reload and
tree navigation do not replay permission or paid work: explicitly reinvoke the
workflow. Reports remain on disk. Use `/egm-exit` to restore the pre-workflow tool
selection once cancellation has settled.

Document publication/repairs remain project-local Markdown only and cannot
change AGENTS/CLAUDE/GEMINI/WATCHDOG/SKILL instruction files. Outside-project
publication and scratch implementation are not supported; retain the proposed
Markdown artifact for the operator instead.

## Verification evidence

Run deterministic checks without keys:

```sh
node --test tests/pi-egm.test.mjs
nix build .#pi-egm .#checks.x86_64-linux.pi-egm --no-link
```

The flake check builds the pinned bundle, checks generated persona bodies and
resource layout, loads it through Pi's real resource loader and a Home
Manager-style store symlink, checks all seven nonautomatic skill discoveries,
executes the loaded scoped tool implementations against mutation/outside-read
attempts, and exercises request capture, fixed stage routing, independent retry
identities, ordering, approval denial, document-only inputs, Stage 8 context,
refinement/override rejection, digest mismatch, reused/missing runtime run IDs
and cancellation correlation.
**Delegation responses in this hermetic check are stubs, not live children.**
On the independent branch the check evaluates Kellanved and Dancer, including
the audited Pi version and Pi-only links. If the separately proposed Crokus target
is present, it is also evaluated without realizing Darwin executables on Linux.
The package, EGM check and baseline `agent-skills-eval` build passed directly on
`main` plus EGM. The installed-runtime offline suite passed all 19 tests; the
hermetic check skips only that mutable-runtime test.

Historical evidence from the original stacked branch additionally included
`pi-bounded-compaction`, the expanded shared-skill check and `crokus-eval`. Those
features and checks are not dependencies of this independent branch.

Targeted nixfmt/deadnix checks and statix checks for the new package/module/test
passed. On the original stacked branch, repository-wide `pre-commit` failed on
unrelated untracked `dancer-hardware.nix` formatting/deadnix and existing statix
warnings in MCP, manual-boot tests, Oleafly and flake code. That historical
failure is not a fresh full-tree lint result for the independent branch; unrelated
files have not been changed as a lint workaround.

An additional opt-in **offline** test checks the operator's installed runtime:

```sh
EGM_PACKAGE="$(nix build .#pi-egm --no-link --print-out-paths)/share/pi-egm" \
PI_PACKAGE_DIR=/absolute/path/to/pi-coding-agent \
PI_SUBAGENTS_PACKAGE="$HOME/.pi/agent/npm/node_modules/pi-subagents" \
node --test tests/pi-egm.test.mjs
```

Use Pi's actual package root for `PI_PACKAGE_DIR`, not its executable. This test
creates a disposable agent configuration, resolves all nine generated profiles
through the installed runtime's public preflight API, and runs `/egm-doctor` in
the **real bundled CLI**, with an empty authentication environment, no context
files, no persistent session and an intentionally nonexistent model. It makes
no model request and changes no live configuration. Recorded locally against
Pi 1.5.2 and pi-subagents 0.88.1: passed. The first doctor attempt caught a real
bundled/unbundled SDK identity mismatch; live export forwarding and the bundled
CLI regression check now cover it.

### Unfinished gates — do not claim official support

1. No operator-approved live reviewer, parent/project/global/prior-result canary
   isolation probe, captured provider request audit or actual model mutation
   attempt has been run. Tool implementation tests are not live-model evidence.
2. Brainstorm, draft and five-phase review have not reached final artifacts in
   a real installed model session. Interactive gate fidelity, resolution-loop
   convergence and complete upstream workflow compliance remain unverified.
3. Large-tree/nested bootstrap orchestrators are not implemented. Only the
   upstream direct-root path (at most five pruned directories) is mapped to
   scoped scouts and parent writes; larger scopes must stop and be narrowed.
4. Review-loop custom persona/standard paths are not implemented; only shipped
   built-ins are accepted. Arbitrary substitutions must not happen silently.
5. No host activation or native Darwin run was performed. Cross-evaluation is
   not native runtime success. Package installation is not upstream acceptance.

Before proposing upstream Pi support, obtain approval for the handoff's bounded
live probes, inspect actual assembled child inputs rather than just final
answers, run brainstorm/draft/review end to end with real human pauses, record
exact pins/runtime/models/artifacts/limitations and verify after operator host
activation. Do not push, publish an issue/PR or claim official support from
these deterministic results alone.
