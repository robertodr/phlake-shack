"""Merge only the sandbox read rules added by this home, never user grants."""

import json
import os
from pathlib import Path
import re
import sys
import tempfile


def read(path, default):
    if path.is_symlink():
        raise ValueError(f"Refusing symlink: {path}")
    return json.loads(path.read_text()) if path.exists() else default


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.NamedTemporaryFile(dir=path.parent, mode="w", delete=False) as f:
        try:
            json.dump(value, f, indent=2)
            f.write("\n")
            f.close()
            os.replace(f.name, path)
        finally:
            Path(f.name).unlink(missing_ok=True)


def rules_list(value):
    if not isinstance(value, list) or not all(
        isinstance(rule, str) and re.fullmatch(r"read_file\(/nix/store/[a-z0-9]{32}-[A-Za-z0-9+._?=-]+\)", rule)
        for rule in value
    ):
        raise ValueError("Invalid managed runtime rules")
    return value


def main(template, settings, state):
    wanted = rules_list(json.loads(template.read_text()))
    old = rules_list(read(state, []))
    cfg = read(settings, {})
    permissions = cfg.setdefault("permissions", {})
    allow = permissions.get("allow", [])
    if not isinstance(allow, list):
        raise ValueError("Expected permissions.allow array")
    kept = [r for r in allow if r not in old or r in wanted]
    added = [r for r in wanted if r not in kept]
    owned = [r for r in wanted if r in old or r in added]
    if allow != kept + added:
        permissions["allow"] = kept + added
        write(settings, cfg)
    if owned != old:
        write(state, owned)


if __name__ == "__main__":
    main(*map(Path, sys.argv[1:]))
