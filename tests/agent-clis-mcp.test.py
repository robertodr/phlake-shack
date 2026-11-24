"""Check rendered client configs, not just their Home Manager inputs."""

import json
from pathlib import Path
import shlex
import sys
import tomllib

codegraph, codex, gemini, pi, claude = map(Path, sys.argv[1:])
servers = {
    "codegraph": {"command": str(codegraph), "args": ["serve", "--mcp"]},
    "notion": {"url": "https://mcp.notion.com/mcp"},
    "paperpile": {"url": "https://mcp.paperpile.com/"},
}


def check(client, actual, expected):
    assert actual == expected, f"{client}: expected {expected!r}, got {actual!r}"


check("codex", tomllib.loads(codex.read_text())["mcp_servers"], servers)
check("antigravity", json.loads(gemini.read_text())["mcpServers"], {
    name: {"serverUrl": entry["url"]} if "url" in entry else entry
    for name, entry in servers.items()
})
check("pi", json.loads(pi.read_text())["mcpServers"], {
    name: {"args": [], "env": {}, "headers": {}, **entry}
    for name, entry in servers.items()
})

# Inspect the plugin actually passed to Claude, without launching any client.
command, = [shlex.split(line) for line in claude.read_text().splitlines()
            if line.startswith("exec ")]
plugins = [Path(path) for flag, path in zip(command, command[1:]) if flag == "--plugin-dir"]
plugin, = [p for p in plugins if json.loads((p / ".claude-plugin/plugin.json").read_text())["name"]
           == "claude-code-home-manager"]
check("claude", json.loads((plugin / ".mcp.json").read_text())["mcpServers"], {
    name: {**entry, "type": "http" if "url" in entry else "stdio"}
    for name, entry in servers.items()
})
