# Bounded Pi compaction

The Pi profile installs `bounded-compaction` globally through Home Manager, alongside
these settings:

```json
{
  "compaction": {
    "keepRecentTokens": 8000,
    "reserveTokens": 32768
  }
}
```

`keepRecentTokens` is an approximate retained-transcript target, not a hard limit.
`reserveTokens` controls how early compaction starts, not summary length.
Model selection, reasoning levels, tool exposure, and prompt caching are unchanged.

## Why an extension

Pi appends cumulative `<read-files>` and `<modified-files>` inventories *after*
generating its summaries. Asking `/compact` for a shorter summary cannot bound
those lists. One historical session's 386,000-character checkpoint contained
356,000 characters of file inventories.

The extension reuses Pi's `compact()` implementation for the summary, split-turn
handling, validation, and retries, with current authentication resolved through
`ctx.modelRegistry.streamSimple()`:

- Strip old inventory/archive blocks before resummarizing, including legacy
  checkpoints created without this extension.
- Prefer active requirements, current state, blockers, decisions, and next steps;
  request **2,000–4,000 narrative tokens**. This is a soft target, not a hard cap.
- Include at most **40 paths and 6,000 rendered characters**, including XML tags.
  Files touched in the newly summarized messages take priority over historical
  artifacts. Nested codemode read/edit/write calls count too.
- Render paths within the working directory relatively; retain exact absolute
  paths for other worktrees. Never truncate a pathname.
- Keep the complete inventory in off-context compaction metadata and a private
  JSON archive. Old messages and summaries in the session file are not rewritten.
- Retain Pi's original `firstKeptEntryId`, so tool-call/result boundaries and the
  retained recent transcript remain intact.

Archives live under the session directory:

```text
compaction-inventories/<session-id>/<unique-id>.json
```

Directories are created with mode `0700`, archives with `0600`. The checkpoint
contains its archive path and advises selective retrieval, rather than loading
the full inventory. `/compaction-inventory` displays the latest archive path and
file counts without making a model request. Full inventories are reconstructed
from the active branch's checkpoint metadata, not process-global state, so
resume, forks, and tree navigation do not leak abandoned-branch inventories.

Archive writes and summary errors fail closed: compaction is cancelled instead
of silently falling back to unbounded inventories. Empty, truncated, or cancelled
summaries are not saved. A failed attempt can leave an unused archive; it contains
only file inventories and can be removed after checking that no checkpoint refers
to it.

This hook customizes compaction, not `/tree`'s separate branch-summary generator.
It does not immediately rewrite an already-loaded checkpoint or guarantee a
particular total post-compaction context size.

## Activate

The generated `~/.pi/agent/settings.json` is an immutable Home Manager symlink;
do not edit it directly. Apply the normal host configuration, then run `/reload`
in Pi. For example, on Kellanved, `path:` includes new files before Git staging:

```sh
sudo nixos-rebuild switch --flake path:.#kellanved
```

Review unrelated working-tree changes before switching: a system rebuild includes
them too. Alternatively, stage the intended new files and use the normal Git-backed
flake command. No automatic system activation is performed by the tests.

In a resumed session, run `/compact` once to replace its existing oversized
checkpoint, then `/compaction-inventory` to locate the archive. Pi's context meter
becomes reliable after the next assistant response. The next checkpoint uses the
smaller retained-history setting; `/reload` alone does not compact history.

For a temporary extension-only trial without activating Home Manager:

```sh
pi -e ./homes/profiles/pi-coding-agent/bounded-compaction/index.ts
```

That invocation does not change the installed retention settings. Do not also
load it with `-e` after Home Manager has installed it globally.

## Validation

```sh
nix build path:.#checks.x86_64-linux.pi-bounded-compaction --no-link
```

The check evaluates settings and extension links for Kellanved, Dancer, and
Crokus, then runs Node tests using the pinned native Pi loader and compactor with
mocked provider responses (no credentials or model requests). Tests cover size
limits, legacy inventories, repeated compaction, metadata exclusion from model
context, branch changes, split turns, permissions, failures, and cancellation.
Cross-evaluation does not test native Darwin execution or system activation.

The pure inventory tests can also run with Node 24:

```sh
node --test tests/pi-bounded-compaction.test.mjs
```

Set `PI_PACKAGE_DIR` to Pi's installed `lib/node_modules/@earendil-works/pi-coding-agent`
directory to include the integration tests outside Nix; otherwise they are skipped.

## Tuning and rollback

The inventory limits are constants in
`homes/profiles/pi-coding-agent/bounded-compaction/inventory.ts`; the summary policy
is `FOCUS` in `index.ts`. Retention settings live in the profile's `default.nix`.

To disable, remove the `extensions/bounded-compaction` Home Manager file entry
and the compaction settings, activate again, and `/reload`. Already-created
checkpoints remain valid, and archives/session history are left untouched.
