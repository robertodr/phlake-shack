import { constants } from "node:fs";
import { open, realpath, readdir, stat } from "node:fs/promises";
import { dirname, isAbsolute, relative, resolve } from "node:path";

export const MAX_FILES = 128;
export const MAX_BYTES = 1024 * 1024;
export const SNAPSHOTS = Symbol.for("phlake.pi-egm.snapshots.v1");
export function registry() {
  return globalThis[SNAPSHOTS] ??= new Map();
}
export function inside(root, path) {
  const rel = relative(root, path);
  return rel === "" || (!isAbsolute(rel) && rel !== ".." && !rel.startsWith("../"));
}
export function boundedText(text, maximum = MAX_BYTES) {
  if (typeof text !== "string" || !text.trim() || Buffer.byteLength(text) > maximum || text.includes("\0")) {
    throw new Error(`Expected nonempty text, without NUL, at most ${maximum} bytes`);
  }
  return text;
}

// Expand first, approve the exact canonical inventory, then read. Directory
// traversal never follows symlinks or discovers ambient instruction files.
export async function inventory(paths, cwd) {
  if (!Array.isArray(paths) || paths.length > 16) throw new Error("At most 16 input paths");
  const files = new Set();
  async function visit(path, depth) {
    if (depth > 16) throw new Error("Reference directory is too deep");
    const info = await stat(path);
    if (info.isDirectory()) {
      for (const entry of (await readdir(path, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name))) {
        if (entry.name.startsWith(".") || ["node_modules", "vendor", "build", "dist"].includes(entry.name)) continue;
        if (entry.isFile() || entry.isDirectory()) await visit(resolve(path, entry.name), depth + 1);
      }
    } else if (info.isFile()) {
      files.add(path);
      if (files.size > MAX_FILES) throw new Error(`More than ${MAX_FILES} files; narrow the reading list`);
    } else throw new Error("Only regular files and directories can be reviewed");
  }
  for (const input of paths) {
    boundedText(input, 4096);
    await visit(await realpath(resolve(cwd, input)), 0);
  }
  return [...files].sort();
}

export async function capture(files) {
  const entries = [];
  let bytes = 0;
  if (files.length > MAX_FILES) throw new Error("Too many files");
  for (const path of files) {
    if (await realpath(path) !== path) throw new Error("Snapshot path was redirected after approval");
    const handle = await open(path, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    try {
      const before = await handle.stat();
      if (!before.isFile() || before.size > MAX_BYTES - bytes) throw new Error("Snapshot exceeds 1 MiB or is not a regular file");
      const data = await handle.readFile();
      bytes += data.length;
      const after = await handle.stat();
      const current = await stat(path);
      if (await realpath(path) !== path || current.dev !== after.dev || current.ino !== after.ino
          || bytes > MAX_BYTES || before.size !== after.size || before.mtimeMs !== after.mtimeMs) {
        throw new Error("Snapshot changed while being read or exceeds 1 MiB");
      }
      const text = new TextDecoder("utf-8", { fatal: true }).decode(data);
      if (text.includes("\0")) throw new Error("Binary reference; provide a text extract instead");
      entries.push({ path, text });
    } finally { await handle.close(); }
  }
  return entries;
}

// These operations have no filesystem access. Paths are canonical snapshot keys,
// not paths the reviewer can use to make the host open another file.
export function snapshotOperations(entries, cwd, audit = []) {
  const files = new Map(entries.map(({ path, text }) => [path, text]));
  function record(value) {
    if (audit.length >= 128) throw new Error("Snapshot audit capacity exhausted; no further reads executed");
    audit.push(value);
  }
  function selected(input) {
    boundedText(input, 4096);
    const path = resolve(cwd, input.replace(/^@/, ""));
    if (!files.has(path)) throw new Error("Path is outside the approved snapshot");
    return { path, text: files.get(path) };
  }
  function limit(text) {
    const lines = text.split("\n");
    const kept = [];
    let bytes = 0;
    for (const line of lines.slice(0, 2000)) {
      if (bytes + Buffer.byteLength(line) + 1 > 48000) break;
      kept.push(line); bytes += Buffer.byteLength(line) + 1;
    }
    return kept.join("\n") + (kept.length < lines.length ? "\n[Truncated; use read with offset/limit]" : "");
  }
  return {
    read({ path, offset = 1, limit: count = 2000 }) {
      if (!Number.isSafeInteger(offset) || offset < 1 || !Number.isSafeInteger(count) || count < 1 || count > 2000) {
        throw new Error("Invalid line range");
      }
      const file = selected(path);
      const output = limit(file.text.split("\n").slice(offset - 1, offset - 1 + count).map((line, i) => `${offset + i}: ${line}`).join("\n"));
      record({ tool: "read", path: file.path, offset, requestedLines: count, outputBytes: Buffer.byteLength(output), truncated: output.includes("[Truncated;") });
      return output;
    },
    grep({ pattern, path }) {
      boundedText(pattern, 512);
      const rows = [];
      const candidates = path ? [selected(path)] : [...files].map(([path, text]) => ({ path, text }));
      for (const file of candidates) {
        record({ tool: "grep", path: file.path });
        file.text.split("\n").forEach((line, i) => {
          if (line.includes(pattern)) rows.push(`${file.path}:${i + 1}: ${line}`);
        });
      }
      return limit(rows.join("\n") || "No matches in approved snapshot");
    },
    find({ pattern = "" }) {
      if (typeof pattern !== "string" || pattern.length > 512) throw new Error("Invalid pattern");
      record({ tool: "find" });
      return limit([...files.keys()].filter(path => path.includes(pattern)).join("\n") || "No approved files match");
    },
    ls() {
      record({ tool: "ls" });
      return limit([...files.keys()].join("\n"));
    },
  };
}

export async function artifactPath(root, name) {
  if (typeof name !== "string" || !/^[a-zA-Z0-9][a-zA-Z0-9._-]{0,119}\.md$/.test(name)) {
    throw new Error("Artifact must be a simple Markdown filename");
  }
  if (await realpath(root) !== resolve(root)) throw new Error("Artifact directory was redirected");
  const path = resolve(root, name);
  if (!inside(root, path) || dirname(path) !== root) throw new Error("Artifact path escapes output directory");
  return path;
}
