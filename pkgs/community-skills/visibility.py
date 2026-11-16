"""Apply declarative visibility without reserializing upstream YAML or bodies."""

import json
from pathlib import Path
import re
import sys


def configure(text, visible):
    match = re.fullmatch(r"---\n(.*?)\n---(\n.*)", text, re.DOTALL)
    if match is None:
        raise ValueError("Expected a SKILL.md with YAML frontmatter")
    frontmatter, body = match.groups()
    frontmatter = re.sub(
        r"^disable-model-invocation:[^\n]*(?:\n|$)",
        "",
        frontmatter,
        flags=re.MULTILINE,
    ).rstrip("\n")
    if not visible:
        frontmatter += "\ndisable-model-invocation: true"
    return f"---\n{frontmatter}\n---{body}"


def main():
    root = Path(sys.argv[1])
    visible = set(json.loads(sys.argv[2]))
    paths = {path.parent.name: path for path in root.glob("*/*/SKILL.md")}
    if visible - paths.keys():
        raise ValueError("Visibility policy contains unknown skills")
    for name, path in paths.items():
        path.write_text(configure(path.read_text(), name in visible))


if __name__ == "__main__":
    main()
