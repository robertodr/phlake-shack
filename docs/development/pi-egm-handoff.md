# Handoff: native EGM support for Pi

## Implementation update

An experimental local adapter now exists on the `feat/pi-egm` stack above
`feat/obsidian-skills`. See [the implementation runbook](pi-egm.md) for its exact
pin, API/security mapping, deterministic checks, activation and unfinished gates.
The operator subsequently authorized implementation and commits on a new stacked
branch, but not pushes, activation or paid-model probes.

Implemented: intact pinned runtime packaging; all seven Pi-only skill entry
points; generated upstream leaf profiles; fresh foreground delegation with
preflight/return-digest checks; snapshot-only reviewer tools; bounded stage
routing, retries and artifact delivery; Home Manager wiring; offline checks.
The real bundled CLI's SDK/API identity and backend readiness were also checked
in a disposable, unauthenticated configuration without model requests.

Still outstanding: live reviewer isolation/input audits, complete installed
brainstorm/draft/review evidence, large-tree bootstrap workers, custom
persona/standard paths, host activation and native Darwin execution. The
integration is neither officially supported nor fully verified. The original
requirements below remain the acceptance guide, not a statement of completion.

## Goal and authorization boundary

Implement a declarative, Nix-managed Pi integration for
[Elephant-Goldfish Model (EGM)](https://egm.dev/install/), reusing the installed
`pi-subagents` runtime. EGM is a document-design/review workflow, **not an LLM
provider**: do not add a provider or a `models.json` entry to solve this.

This document originally described an unimplemented adapter. The update above
records the subsequent local implementation; live review tests have not been
run. The operator requested this handoff so a new agent could implement the
integration. Confirm scope for further implementation; this handoff alone does
not authorize publishing PRs, activating host configurations, or running paid
multi-agent workflows.

Do not treat inspecting EGM's workflow instructions as entering an EGM design
session. Conversely, once an operator actually invokes an EGM workflow, preserve
its design-only scope and approval gates; do not globally impose those rules on
ordinary Pi coding sessions.

## Current project state

Repository: `/home/roberto/phlake-shack`.

At the original handoff the active branch was `feat/obsidian-skills`, with commit `f17fe1d`,
stacked above `feat/oleafly` (PR #18), itself above `feat/crokus-home-manager`
(PR #17). Reinspect the actual stack before any version-control operation.
Do not silently add EGM work to an existing PR or push any branch.

Preserve unrelated untracked files:

- `dancer-facter.json`
- `dancer-hardware.nix`
- `docs/research/`

Relevant existing integration points:

| File | Purpose |
| --- | --- |
| `homes/profiles/pi-coding-agent/default.nix` | Pi package, settings/packages, extension links and update timer |
| `homes/profiles/agent-skills/default.nix` | Shared Pi/Claude skill directory allowlist |
| `pkgs/obsidian-skills/default.nix` | Example of pinned skill-only packaging; **not sufficient for EGM** |
| `pkgs/but-skills/default.nix` | Existing `installAgentSkills` packaging pattern |
| `tests/agent-skills-eval.nix` | Linux and Darwin Home Manager link evaluation and Linux file checks |
| `docs/development/agent-skills.md` | Existing skill adoption/activation policy |
| `flake.nix` | Host wiring and `checks.x86_64-linux` registration |

Pi already loads `npm:pi-subagents`; do not install another delegation framework.
The Home Manager module sets `useBun = false`. Preserve that choice: prior work
fixed host SDK/TypeBox resolution using the Node layout. Pi packages currently
update imperatively through the configured extension update mechanism, so a
pinned EGM source does **not** by itself pin the subagent runtime.

Research observed Pi 1.5.2 and `pi-subagents` 0.88.1. Recheck installed versions
and public APIs rather than assuming they are unchanged. Installation does not
mean this session has already authorized child-agent execution.

## Upstream baseline and required reading

Upstream EGM inspected at commit:

```
72d06f52a2482885d9a64bd24b291c6e8628942c
```

Its `plugin.json` reported version 0.1.1 and Apache-2.0 licensing. This is a
research baseline, not an instruction to track mutable `main` without review.
Choose and hash-pin the source revision during implementation.

Read the complete relevant upstream files, including their referenced protocols:

- https://github.com/google/elephant-goldfish-model/blob/main/docs/harnesses.md
- `README.md`, `plugin.json`, `resources/execution_instructions.md`
- `skills/egm-review/SKILL.md`, `skills/egm-brainstorm/SKILL.md`,
  `skills/egm-draft/SKILL.md`, and the other skill definitions
- Required `agents/*.md` personas and `resources/document_standards/*.md`
- `TESTING.md`, plus `CONTRIBUTING.md`, `AGENTS.md`, and `AI_POLICY.md` before
  modifying the upstream repository or proposing an upstream contribution

Pi is not listed as officially supported in the inspected harness guide. `omp`
is listed and uses `/skill:egm-…`; that is useful precedent, **not evidence that
Pi can consume omp/Claude manifests or dispatch tools unchanged**.

Upstream explicitly says to install the whole runtime bundle, not `skills/`
alone. Skills read sibling `agents/`, `resources/`, and `docs/` at runtime.
Goldfish reviews must stop when fresh-context delegation is unavailable. Upstream
also distinguishes parent-turn isolation from exclusion of instruction files.

Before implementing Pi changes, read the relevant installed Pi documentation
and examples in full, following cross-references. Obtain paths from the current
harness instructions; the research installation used:

```
/nix/store/r9l3jv5xhpxb9r9nfaz0mw4hf5jb3lgc-pi-1.5.2/lib/node_modules/@earendil-works/pi-coding-agent/
```

Relevant Pi docs: `docs/packages.md`, `docs/skills.md`, `docs/extensions.md`,
`docs/sdk.md`, `docs/settings.md`, and the corresponding package/extension
examples. Do not resolve these paths against the configuration repository.

The installed subagent documentation was under:

```
~/.pi/agent/npm/node_modules/pi-subagents/docs/
```

Read `agents.md`, `tool-reference.md`, `extension-api.md`, `configuration.md`,
`workflows.md`, and the tool-permission sections of `watchdog.md`. Check their
installed versions before copying examples. Do not rely on private `src/`
imports as a stable integration API.

## Non-negotiable behavior

### Genuine fresh reviewers

- The Elephant is the existing drafting session; each Goldfish is a new child.
- Every Goldfish launch explicitly requests `context: "fresh"`. Defaults are
  insufficient: global/per-agent preferences can change to `fork`.
- Never fork the parent transcript, summarize it into the review task, or append
  its earlier decisions as unstated reviewer assumptions.
- Pass the selected persona, phase instructions, document, review criteria and
  only the references authorized by that upstream stage.
- Comprehension/document-only phases must not receive the broader reading list.
- Do not resume a previous Goldfish to obtain a supposedly independent review
  in a later round. Use distinct children and distinct run/result identifiers.
- If the contract cannot be established, report the limitation and stop. A
  same-session imitation must never be labeled a Goldfish review.

Configure inherited project/global instructions and ambient skills deliberately.
For fresh reviewer profiles, the installed runtime documents these controls:

```yaml
systemPromptMode: replace
inheritProjectContext: false
inheritGlobalContext: false
inheritSkills: false
defaultContext: fresh
```

These do not justify removing mandatory harness safety/authorization rules.
They also do not sanitize an explicitly forked parent prompt: **fresh mode must
be selected at launch**, regardless of profile defaults.

### Read-only reviewer execution

Use an enforced child-tool allowlist, not merely a sentence asking reviewers not
to edit. A starting profile can allow `read, grep, find, ls`, with no `bash`,
`write`, `edit`, unrestricted `codemode`, MCP tools or nested delegation.
Check the actual installed tool schemas and enforce the resolved launch contract.
`acceptanceRole: read-only` is diagnostic/acceptance metadata, **not permission
enforcement**.

Disable ambient extensions and persistent reviewer memory unless explicitly
needed and audited. Check required host extensions too: the installed runtime
says they can still load even when `extensions` is empty. Reject unexpected
capabilities rather than assuming an agent filename or empty extension list is
sufficient. Protect against project agent definitions or settings overrides
silently widening an EGM profile's capabilities.

Read-only tools are not an OS sandbox and do not themselves restrict which files
can be read. If claiming document/reference confinement, enforce canonical-path
read boundaries through supported permissions or a scoped reader. At minimum,
document-only stages must not preload additional files, and validation must
inspect actual reads. Do not claim filesystem or credential isolation that was
not implemented and tested.

Reviewers return findings; the parent/trusted adapter saves reports to approved
artifact paths. This permits artifact delivery without giving reviewers arbitrary
file-write tools. Review output does not authorize edits to production code.

### Workflow and human control

Preserve upstream phase ordering, criteria, human approval transitions and
single-question gates. Use direct parent dispatch initially; do not require
nested synthesizer agents for the first integration. If upstream requires
specific synthesis behavior, preserve it explicitly rather than silently dropping
stages. Distinguish leaf reviewers from bootstrap/synthesis orchestrators.

User invocation of a review authorizes its explained, bounded delegation; merely
installing EGM, loading its catalog, or discussing setup does not. Bound fanout,
rounds, concurrency and runtime, and expose failures/cancellation/costs. Do not
start a full multi-stage live-model test without operator approval. Do not
globally change other agents' delegation/model/context defaults.

## Proposed packaging and integration

These paths are proposals, not existing files or a required API:

```
pkgs/pi-egm/default.nix
homes/profiles/pi-coding-agent/egm/
  package.json
  index.ts
  ...small adapter helpers/profile templates as needed...
tests/pi-egm*.nix
tests/pi-egm*.test.mjs
docs/development/pi-egm.md
```

1. Pin EGM with a fixed revision/hash; retain its Apache license and runtime
   files. Keep the relative `skills/<name>/../../agents|resources|docs` layout.
2. Add a small Pi package/extension wrapper referencing that immutable bundle.
   Preserve all seven skills: `egm-brainstorm`, `egm-draft`, `egm-review`,
   `egm-review-loop`, `egm-resolve`, `egm-bootstrap`, `egm-drift-report`.
3. Load it through the existing Pi Home Manager module. Make the bundle root
   explicit to the adapter and use canonical resource paths; test resolution
   through actual Home Manager symlinks and the Nix store, not just a checkout.
4. Generate or configure reviewer profiles from upstream personas without
   maintaining a forked copy of their substantive prompts. Apply Pi-specific
   tool/context constraints in the adapter layer.

Do **not** simply run `installSkill` for each EGM directory using the Obsidian
recipe: flattening directories can break sibling references. Pi's advertised
skill path, symlink traversal and lexical path normalization need real tests.
A wrapper exposing the intact upstream `skills/` tree through a Pi package is
preferable to globally installing broken flat links.

Do not add Pi-specific EGM wrappers to the shared Pi/Claude allowlist by default.
Claude support is a different plugin installation contract. Keep Pi-only glue
Pi-only; do not claim that the adapter installs or verifies EGM for Claude.

Preserve `disable-model-invocation` where upstream declares it. Expected Pi
invocation is `/skill:egm-review path/to/design.md`, not an assumed Claude-style
`/egm:egm-review` command. Add short aliases only deliberately and document them.

## Delegation seam: reuse pi-subagents

The installed runtime provides two relevant public integration mechanisms:

- Event-bus RPC: `subagents:rpc:v1:ready`, `…:request`, and the matching reply
  events; methods include `ping`, `spawn`, `status`, `stop` and `cost`.
- Trusted workflow resources: `registerWorkflowResource` from the documented
  `pi-subagents/workflow-resources` entry point, invoked through the public
  subagent workflow interface.

Choose the smallest supported seam after reading the installed docs. Event-bus
RPC is attractive for a Nix-store extension because it avoids assuming that
`import "pi-subagents/…"` resolves from a read-only store directory to a mutable
package in the user's npm extension tree. If using direct imports, prove module
resolution in the actual installed layout; do not hardcode `/home/roberto` or
bundle a second runtime/host SDK/TypeBox just to make imports work.

For RPC, follow its documented lifecycle/readiness and request correlation;
`spawn` is async-only in the inspected version. Query capabilities and validate
resolved child profiles before dispatch. Handle missing/late backend readiness,
reloads, timeouts, error replies and interrupted runs. Do not invent or copy a
schema from a different extension version.

For trusted resources, register by the actual session ID, dispose on shutdown/
reload, and follow its bounded, synchronous resolver contract. Do not interpolate
user text into executable workflow source without proper data serialization.
Host-command grants are not a sandbox; no shell grants should be needed for a
read-only document review.

Neither seam should reimplement the subagent scheduler, provider authentication,
model routing, persistence or fleet UI. Respect existing tool activation and
operator authorization. Start with native local Pi children, not external CLI,
remote or terminal-multiplexer runners; those add different isolation contracts.

## Implementation sequence

### 1. Inspect and decide

Read the docs, inspect the current module/configuration, and record versions.
Identify the public delegation seam and an enforceable launch contract. Confirm
any materially different scope/security design with the operator before coding.
Keep source persona/rubric text upstream; decide how canonical paths and managed
reviewer profiles will be provided without mutating unrelated agent settings.

### 2. Prove one isolated reviewer

Build a clearly labeled smoke/prototype path, not a falsely complete
`egm-review`. Run one leaf persona against a disposable Markdown fixture with
explicit fresh context and read-only tools. Verify inputs and mutation denial
before connecting the complete upstream protocol. Request approval before a
live paid-model probe; deterministic SDK/runtime tests should run without keys.

### 3. Wire the complete review protocol

Expose `egm-review` only once it performs the upstream review phases and gates.
Use bounded direct dispatch, collect findings, and let the trusted parent save
reports. Cover failed/cancelled children, partial results, reviewer independence
between rounds, approved references and artifact delivery. Do not label a
one-persona smoke test as a completed five-phase EGM review.

### 4. Add the other workflows

Wire brainstorm and draft, then resolve/review-loop/bootstrap/drift-report,
preserving their distinct contracts. Do not treat document-only drafting as
proof that the Goldfish integration works. Default all design workflows to
non-production changes and require explicit approval transitions.

### 5. Package, validate and document

Add flake checks, build the package, evaluate all relevant Home Manager targets,
and document activation/reload and provider/model requirements. Do not switch
host configurations, move vaults, write user credentials, or modify live global
agent instructions as a testing shortcut. The operator performs activation.

## Acceptance tests and evidence

### Deterministic checks (no paid model)

- Fixed source/hash, expected skill/persona/standard files and license exist.
- Relative links resolve from the installed store package and configured paths.
- Discovery has no duplicate names, and normally non-automatic skills stay so.
- Generated profiles have the expected fresh-context/inheritance/tool contract;
  verify runtime resolution too, not only YAML text.
- Stub/capture delegation requests: explicit fresh mode, correct persona/phase,
  only approved references, bounded fanout and no fork/resume substitution.
- Hostile document text cannot expand tool permissions, spawn extra children,
  escape artifact paths or inject host/workflow commands.
- Missing/unsupported backend and widened/shadowed reviewer profiles fail closed.
- Approval gates really pause; an error is not recorded as a successful review.
- Reload/disposal is idempotent; completion correlation and cancellation work.
- Reviewers cannot write fixtures or invoke an undeclared tool; parent report
  writes remain confined to the approved artifact directory.
- Evaluate Linux hosts and Crokus without realizing Darwin executables on Linux.

### Isolation probes (operator-approved live runs)

Use a temporary project/configuration; do not alter real user AGENTS files.
Place distinct random canaries only in the parent conversation, project
instruction fixture, global instruction fixture and an earlier review result.
Keep them out of the reviewed document and approved references.

Inspect the actual assembled child inputs/transcripts or captured model requests
where supported. Absence of a canary in the final answer alone is **not proof**
that it was absent from the input. Test both foreground and background modes if
both are exposed. Otherwise deliberately support one mode and document it.

Check separately:

1. Parent conversation does not reach the child.
2. Project/global drafting assumptions are not injected as instruction files.
3. Ambient skills, extensions and persistent reviewer memory do not reintroduce
   that context.
4. A later independent child does not inherit a prior review's session/report
   unless the upstream stage explicitly authorizes that input.
5. Mutation attempts fail and leave the filesystem canaries unchanged.

### End-to-end workflow gate

On the installed adapter, run brainstorm, draft and review to their real final
artifacts, preserving human pauses. Exercise both interactive and explicitly
uninterrupted modes if advertised. Record exact source/runtime versions,
commands, selected models, capabilities, artifact paths and limitations. Confirm
behavior on an actual host after operator activation. Native Darwin success is
not established by Linux cross-evaluation.

Passing these workflows is upstream's support bar. Until then describe the
integration as experimental/local, not officially supported or fully verified.

## Non-goals and final handoff

No new LLM provider, automatic implementation/merge, background unsolicited
reviews, new secret storage, cloned subagent engine or changes to the existing
Obsidian/Oleafly work. Do not use council mode as a substitute for EGM's review
protocol. Do not run imperative installers over Home Manager-owned paths.

The implementing agent should finish with:

- Code and tests, exact pins and runtime compatibility checks.
- Clear distinction between deterministic checks, live isolation evidence and
  complete workflows; list any unfinished checks explicitly.
- Instructions for operator activation and canonical Pi commands.
- Disclosure of filesystem-read/sandbox limits and mutable runtime dependencies.
- Documentation suitable for a later upstream Pi-support proposal. Upstream
  expects installation instructions, delegation mapping and end-to-end evidence.

Do not publish upstream issues/PRs, push changes or accept agreements without an
explicit operator request. If committing is requested, follow the repository's
conventional-commit and `Assisted-by: <harness>:<model>` requirements and use the
current GitButler workflow. This handoff is not itself a request to commit.
