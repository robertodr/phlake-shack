import { relative, isAbsolute } from "node:path";
import type { AgentMessage } from "@earendil-works/pi-agent-core";

export interface Inventory {
  readFiles: string[];
  modifiedFiles: string[];
}

export const MAX_INVENTORY_PATHS = 40;
export const MAX_INVENTORY_CHARS = 6000;

// Only remove Pi's explicit inventory blocks, not paths in the narrative.
export function stripInventories(summary: string): string {
  return summary
    .replace(/<(read-files|modified-files|file-inventory-archive)>[\s\S]*?<\/\1>/g, "")
    .trim();
}

export function inventoryFromDetails(details: unknown): Inventory {
  const data = details as Partial<Inventory> | undefined;
  const strings = (value: unknown): string[] =>
    Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
  return {
    readFiles: strings(data?.readFiles),
    modifiedFiles: strings(data?.modifiedFiles),
  };
}

export function inventoryFromMessages(messages: AgentMessage[]): Inventory {
  const inventory: Inventory = { readFiles: [], modifiedFiles: [] };
  // Newest calls first, including tool calls made inside codemode scripts.
  for (const message of [...messages].reverse()) {
    const calls = message.role === "toolResult"
      ? message.nestedCalls?.calls ?? []
      : message.role === "assistant"
        ? message.content.filter((block) => block.type === "toolCall")
        : [];
    for (const call of [...calls].reverse()) {
      const path = call.arguments?.path;
      if (typeof path !== "string") continue;
      if (call.name === "read") inventory.readFiles.push(path);
      if (call.name === "edit" || call.name === "write") inventory.modifiedFiles.push(path);
    }
  }
  return mergeInventories(inventory);
}

export function inventoryFromSummary(summary: string): Inventory {
  const paths = (tag: string): string[] =>
    [...summary.matchAll(new RegExp(`<${tag}>([\\s\\S]*?)<\\/${tag}>`, "g"))]
      .flatMap((match) => match[1].split("\n"))
      .map((line) => line.trim())
      .filter(Boolean);
  return { readFiles: paths("read-files"), modifiedFiles: paths("modified-files") };
}

// Inputs are ordered newest first. A modified file never also appears read-only.
export function mergeInventories(...inventories: Inventory[]): Inventory {
  const modifiedFiles = [...new Set(inventories.flatMap((item) => item.modifiedFiles))];
  const modified = new Set(modifiedFiles);
  const readFiles = [...new Set(inventories.flatMap((item) => item.readFiles))]
    .filter((path) => !modified.has(path));
  return { readFiles, modifiedFiles };
}

export function displayPath(path: string, cwd: string): string {
  if (!isAbsolute(path)) return path;
  const local = relative(cwd, path);
  return local !== ".." && !local.startsWith("../") && !isAbsolute(local) ? local || "." : path;
}

export function formatInventory(inventory: Inventory): string {
  return (["readFiles", "modifiedFiles"] as const)
    .filter((key) => inventory[key].length > 0)
    .map((key) => {
      const tag = key === "readFiles" ? "read-files" : "modified-files";
      return `<${tag}>\n${inventory[key].join("\n")}\n</${tag}>`;
    })
    .join("\n\n");
}

// Bound the actual rendered block, including XML tags. Never truncate a path.
// Prefer files from the newly summarized messages (including reads) over old
// artifacts. A recently read file modified earlier is still marked modified.
export function boundInventory(inventory: Inventory, cwd: string, recent = inventory): Inventory {
  const bounded: Inventory = { readFiles: [], modifiedFiles: [] };
  const modified = new Set(inventory.modifiedFiles);
  const seen = new Set<string>();
  const candidates = [
    ...recent.modifiedFiles, ...recent.readFiles,
    ...inventory.modifiedFiles, ...inventory.readFiles,
  ];
  for (const rawPath of candidates) {
    const path = displayPath(rawPath, cwd);
    if (!path || /[\r\n]/.test(path) || seen.has(path)) continue;
    if (seen.size >= MAX_INVENTORY_PATHS) break;
    const key = modified.has(rawPath) ? "modifiedFiles" : "readFiles";
    bounded[key].push(path);
    if (formatInventory(bounded).length > MAX_INVENTORY_CHARS) {
      bounded[key].pop();
      continue;
    }
    seen.add(path);
  }
  return bounded;
}
