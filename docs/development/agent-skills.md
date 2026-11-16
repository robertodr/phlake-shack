# Shared agent skills

`homes/profiles/agent-skills/default.nix` defines the shared allowlist:
`but`, `herdr`, `qmd`, and five selected official Obsidian skills: `defuddle`,
`json-canvas`, `obsidian-bases`, `obsidian-cli`, and `obsidian-markdown`.
`knap` and `obsidian-headless` are deliberately excluded from both the package
and managed skill links. Home Manager links the same immutable directories
into `~/.agents/skills/` (discovered by Pi) and Claude Code's configured
`skills/` directory. No duplicate links are created in `~/.pi/agent/skills/`.
Other, unmanaged skills may coexist.

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

## First activation: adopt existing copies

Existing imperative installations are not overwritten automatically. Before
switching, inspect and move any existing copies of these skills outside all
agent discovery directories. In particular, the old GitButler directory is
named `gitbutler`, but its declared skill name is `but`. Leaving it installed
alongside the new `but` directory causes duplicate-name warnings.

On the current machine, old GitButler copies exist at:

- `~/.agents/skills/gitbutler`
- `~/.claude/skills/gitbutler`
- `~/.pi/agent/skills/gitbutler`

For example, in Fish, back these up without deleting them:

```fish
set backup (mktemp -d "$HOME/agent-skills-backup.XXXXXX")
for agent in .agents .claude .pi/agent
    set label (string replace -a / - $agent)
    for skill in gitbutler but herdr qmd defuddle json-canvas obsidian-bases obsidian-cli obsidian-markdown
        set source "$HOME/$agent/skills/$skill"
        if test -e "$source"; or test -L "$source"
            mv -- "$source" "$backup/$label-$skill"
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
  pkgs/obsidian-skills/default.nix tests/agent-skills-eval.nix \
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

The check evaluates links for Kellanved, Dancer, and Crokus, verifies identical
sources and no managed Pi-private duplicates, and checks native Linux skill
files, declared names, GitButler reference files, and Obsidian's bundled Canvas,
Bases and Markdown references. It also verifies the excluded skills stay absent,
checks Defuddle is selected on all three hosts, and runs both Linux homes' CLIs
on local HTML to check Markdown extraction and title metadata. Cross-evaluation
is not proof of native Darwin execution, activation, or agent discovery.
