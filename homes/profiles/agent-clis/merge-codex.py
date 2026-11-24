"""Merge HM's generated Codex MCP fields without managing local trust or credentials."""

import os
import sys
import tempfile
from pathlib import Path

import tomlkit


def merge(template, target):
    if target.is_symlink():
        sys.exit(f"Refusing to replace symlink {target}; inspect it before activation")
    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    original = target.read_text() if target.exists() else ""
    config = tomlkit.parse(original)
    servers = config.setdefault("mcp_servers", tomlkit.table())
    managed = tomlkit.parse(template.read_text())
    # Add only our EGM entries. Do not silently replace a native install,
    # redirect a marketplace, or re-enable a plugin disabled by the owner.
    for section, name in (("marketplaces", "egm"), ("plugins", "egm@egm")):
        entry = managed.get(section, {}).get(name)
        if entry is None:
            continue
        table = config.setdefault(section, tomlkit.table())
        if name not in table:
            table[name] = entry
        elif section == "marketplaces" and any(table[name].get(k) != v for k, v in entry.items()):
            sys.exit("Existing Codex egm marketplace differs; reconcile before activation")
    for name, fields in managed["mcp_servers"].items():
        server = servers.setdefault(name, tomlkit.table())
        for key, value in fields.items():
            if server.get(key) != value:
                server[key] = value
    result = tomlkit.dumps(config)
    if result == original:
        return
    with tempfile.NamedTemporaryFile(dir=target.parent, delete=False, mode="w") as tmp:
        try:
            tmp.write(result)
            tmp.close()
            os.replace(tmp.name, target)
        finally:
            Path(tmp.name).unlink(missing_ok=True)


if __name__ == "__main__":
    merge(*map(Path, sys.argv[1:]))
