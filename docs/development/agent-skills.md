# Shared agent skills

`homes/profiles/agent-skills/default.nix` defines the shared allowlist:
`but`, `herdr`, `qmd`, and five selected official Obsidian skills: `defuddle`,
`json-canvas`, `obsidian-bases`, `obsidian-cli`, and `obsidian-markdown`.
`knap` and `obsidian-headless` are deliberately excluded from both the package
and managed skill links. Home Manager links these common immutable directories
into `~/.agents/skills/` (discovered by Pi) and Claude Code's configured
`skills/` directory. The profile also adopts 38 previously imperative community
skills, preserving their narrower Claude selection (see below). No duplicate
links are created in `~/.pi/agent/skills/`. Other, unmanaged skills may coexist.

Herdr and Qmd already ship `share/skills/<package>/<skill>` through
`installAgentSkills`. The pinned GitButler CLI embeds its skill but does not
install that output. `pkgs/but-skills/default.nix` runs the cached CLI's
`but skill install` inside a Nix build sandbox, then uses `installSkill` to
package the whole directory. Its version follows the selected CLI. The hook
comes from the existing unstable pin because the host's stable nixpkgs lacks
it; none of the upstream cached CLI derivations are overridden.

## Official Obsidian skills

`pkgs/obsidian-skills/default.nix` pins
[obsidianmd/obsidian-skills](https://github.com/obsidianmd/obsidian-skills) by
revision and content hash, and uses the same `installAgentSkills` hook to package
an explicit allowlist from `plugins/obsidian/skills/`. Whole-directory links keep
Canvas/Bases/Markdown reference files available. This is shared by Kellanved,
Dancer and Crokus; evaluating Crokus does not build a Darwin package on Linux.

Update the revision/date/hash and review the allowlist together. New upstream
skills do not become enabled automatically. No imperative marketplace or npm
skill installer is run at activation.

The profile also installs `pkgs.defuddle`, providing the `defuddle` executable
used by the Defuddle skill (`defuddle parse <url> --md`). No global npm install
or `npx` download is needed. The pinned stable package supports those flags;
the check exercises local HTML extraction without network access.

Other runtime setup remains separate: Obsidian desktop CLI enablement, account
credentials and vault configuration are not changed. Knap and Obsidian Headless
are not installed by this profile. No sync/publish service is started and no
vault is modified. Previously managed excluded skill links disappear on the
next Home Manager activation; unrelated unmanaged installations are not deleted.

## Previously imperative community skills

`pkgs/community-skills/sources.nix` pins three upstream repositories by commit
and content hash, with explicit per-skill paths:

| Source | Commit | Skills | Claude links |
| --- | --- | ---: | ---: |
| `obra/superpowers` | `b36e0829c6d0140e93cfef2ca599b1b07d4a7797` | 14 | 0 |
| `mattpocock/skills` | `c55ee46073ed923f86ce59a5eb3b6d895095d1b7` | 23 | 23 |
| `vercel-labs/skills` | `d667282815248da03a08a18272b5d2eef9caf77c` | 1 (`find-skills`) | 0 |

All 38 skill-directory tree hashes matched the existing
`~/.agents/.skill-lock.json` registry when adopting these pins. All installed
instruction bodies also matched these upstream versions. This migration does
not upgrade the skills or enable additional automatic workflows.

The package preserves entire skill directories, including scripts, references
and executable permissions, plus each repository's license and source metadata.
It does not execute upstream scripts, install their external tool dependencies,
register plugins/hooks, or adapt Claude-oriented instructions to Pi's tool API.
Runtime permissions and explicit delegation authorization remain separate.

All 38 are linked into `~/.agents/skills/`; only the 23 Matt Pocock skills are
additionally linked into Claude's configured directory, matching the previous
explicit links. No duplicate Pi-private links are needed. This applies to
Kellanved, Dancer and Crokus.

### Declarative visibility

The `autoInvokeSkills` argument in `pkgs/community-skills/default.nix` preserves
the existing Pi visibility policy: only `dispatching-parallel-agents` and
`subagent-driven-development` are automatically advertised. The other 36 have
`disable-model-invocation: true` and remain explicitly invocable with
`/skill:<name>`. Only that metadata field is configured; upstream descriptions,
instruction bodies and other files are retained.

Change `autoInvokeSkills` in Nix (or pass it from the profile), rebuild, and
reload Pi to change visibility. `/toggle-skills` edits files in place and cannot
persist changes to these immutable store-backed skills. It also cannot maintain
independent visibility for two clients sharing the same file.

Updates require reviewing the source commit, hash and allowlist together.
New upstream skills are not adopted automatically. Do not run `skills update`
or other imperative installers against these managed paths. The old installer
registry is not managed or automatically pruned; retain it as migration evidence,
not as the source of truth for the adopted skills. Package-provided skills from
`pi-subagents` and `pi-starship` remain part of their existing Pi npm packages;
this migration does not change their mutable runtime installation.

## First activation: adopt existing copies

Existing imperative installations are not overwritten automatically. Before
switching, inspect and move any existing copies of these skills outside all
agent discovery directories. In particular, the old GitButler directory is
named `gitbutler`, but its declared skill name is `but`. Leaving it installed
alongside the new `but` directory causes duplicate-name warnings.

Check for legacy GitButler copies at:

- `~/.agents/skills/gitbutler`
- `~/.claude/skills/gitbutler`
- `~/.pi/agent/skills/gitbutler`

For example, from the repository root in Fish, first obtain the exact community
allowlist without fetching or installing anything:

```fish
set community_skills (nix eval --raw --file ./pkgs/community-skills/sources.nix --apply 'sources: builtins.concatStringsSep "\\n" (builtins.concatMap (source: builtins.attrNames source.skills) (builtins.attrValues sources))')
count $community_skills # Must print 38; stop if evaluation failed.
```

Inspect the existing copies before running the following **one-time** backup.
Do not use this after Home Manager already owns these links. The existing 38
shared directories and Pi-private duplicate links must be moved aside; backing
up only Claude's links would leave Home Manager collisions and Pi duplicates.
The backup retains the directory hierarchy so relative symlinks remain useful:

```fish
set backup (mktemp -d "$HOME/agent-skills-backup.XXXXXX")
if test -f "$HOME/.agents/.skill-lock.json"
    mkdir -p "$backup/.agents"
    cp -- "$HOME/.agents/.skill-lock.json" "$backup/.agents/"
end
for agent in .agents .claude .pi/agent
    mkdir -p "$backup/$agent/skills"
    for skill in gitbutler but herdr qmd defuddle json-canvas obsidian-bases obsidian-cli obsidian-markdown $community_skills
        set source "$HOME/$agent/skills/$skill"
        if test -e "$source"; or test -L "$source"
            mv -- "$source" "$backup/$agent/skills/$skill"
        end
    end
end
echo "Backups: $backup"
```

This is a one-time migration for unmanaged copies, not a command to repeat
after Home Manager owns the links. Inspect any additional plugin-provided
copies separately; do not remove unrelated skills or plugins.

Before a Git-backed flake rebuild, register the new files with Git:

```sh
git add homes/profiles/agent-skills/default.nix pkgs/but-skills/default.nix \
  pkgs/obsidian-skills/default.nix pkgs/community-skills/ \
  tests/agent-skills-eval.nix tests/community-skills.test.py \
  docs/development/agent-skills.md
```

Activate your usual host configuration, then run `/reload` in Pi and restart
Claude Code. The GitButler skill retains upstream's
`disable-model-invocation: true`; its canonical name is `but`.

Do not run imperative skill installers against the managed directories.
Upgrades happen through the pinned packages and a Home Manager activation.
Tool configuration, library indexing, credentials, MCP servers, and Herdr's
Pi extension are separate from these skill files.

## Validation

```sh
# path: includes new files even before they are registered with Git.
nix build path:.#checks.x86_64-linux.agent-skills-eval --no-link
```

The check evaluates links for Kellanved, Dancer, and Crokus, verifies common
sources, the preserved community Claude selection and no managed Pi-private
duplicates, and checks native Linux skill files and declared names. For both
Linux homes it checks all 38 community directories against their pinned source
files, executable permissions, instruction bodies and parsed YAML metadata,
including the two-visible/36-hidden policy, licenses and provenance. It exercises
visibility rewriting on fixture metadata without running any upstream scripts.

It also verifies GitButler and Obsidian reference files, checks that excluded
Obsidian skills stay absent, checks Defuddle is selected on all three hosts, and
runs both Linux homes' CLIs on local HTML to check Markdown extraction and title
metadata. Cross-evaluation and file checks are not proof of native Darwin
execution, activation, live skill compatibility, or actual agent discovery.
