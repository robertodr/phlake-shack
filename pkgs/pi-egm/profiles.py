"""Generate Pi-only launch constraints; substantive persona text stays upstream."""
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
profiles = root / "reviewers"
profiles.mkdir()
def profile(name, body):
    fields = {
        "name": f"pi-egm.{name}",
        "description": f"Isolated EGM leaf: {name}",
        "tools": "read, grep, find, ls",
        "extensions": str(root / "adapter" / "reader.ts"),
        "systemPromptMode": "replace",
        "inheritProjectContext": False,
        "inheritGlobalContext": False,
        "inheritSkills": False,
        "defaultContext": "fresh",
        "async": False,
        "timeoutMs": 300000,
        "acceptanceRole": "read-only",
        "allowNestedSubagents": False,
        "defaultProgress": False,
    }
    frontmatter = "\n".join(f"{key}: {json.dumps(value)}" for key, value in fields.items())
    (profiles / f"{name}.md").write_text(f"---\n{frontmatter}\n---{body}")


for source in sorted((root / "agents").glob("*.md")):
    if source.stem in {"synthesizer", "bootstrap_orchestrator"}:
        continue  # Orchestrators are not leaf reviewers.
    _, header, body = source.read_text().split("---", 2)
    name = next(line[6:] for line in header.splitlines() if line.startswith("name: "))
    profile(name, body)

# The bootstrap scout is defined in its skill, not agents/. Extract it rather
# than keeping a local copy of the substantive prompt.
bootstrap = (root / "skills/egm-bootstrap/SKILL.md").read_text()
scout = bootstrap.split("*   `system_prompt`: >- ", 1)[1].split("    *   `enable_write_tools`", 1)[0]
profile("goldfish-explorer", "\n\n" + " ".join(line.strip() for line in scout.splitlines()) + "\n")
