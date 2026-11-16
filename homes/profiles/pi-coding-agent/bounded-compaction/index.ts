import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import {
  compact,
  type ExtensionAPI,
  type FileOperations,
} from "@earendil-works/pi-coding-agent";
import {
  boundInventory,
  formatInventory,
  inventoryFromDetails,
  inventoryFromMessages,
  inventoryFromSummary,
  mergeInventories,
  stripInventories,
  type Inventory,
} from "./inventory.ts";

const FOCUS = `Checkpoint policy (supersedes the earlier preserve-all instruction):
Aim for 2,000–4,000 tokens of narrative, not a cumulative activity log.
Preserve active requirements, user preferences, current state, unresolved issues,
important decisions, and immediate next steps. Collapse completed work and omit
obsolete history, reproducible logs, and exhaustive file inventories. Keep exact
paths and commands where they are necessary to continue safely. File inventories
are managed separately; do not reproduce their XML blocks or old archive links.`;

function fromOps(ops: FileOperations): Inventory {
  return {
    readFiles: [...ops.read],
    modifiedFiles: [...ops.edited, ...ops.written],
  };
}

export default function (pi: ExtensionAPI) {
  pi.on("session_before_compact", async (event, ctx) => {
    const { preparation, signal } = event;
    try {
      signal.throwIfAborted();
      if (!ctx.model) throw new Error("No model selected");

      const previous = [...event.branchEntries].reverse().find((entry) => entry.type === "compaction");
      const messages = [...preparation.messagesToSummarize, ...preparation.turnPrefixMessages];
      const priorInventory = inventoryFromDetails(previous?.details);
      const recent = inventoryFromMessages(messages);
      const full = mergeInventories(
        recent,
        fromOps(preparation.fileOps),
        priorInventory.readFiles.length || priorInventory.modifiedFiles.length
          ? priorInventory
          : inventoryFromSummary(preparation.previousSummary ?? ""),
      );
      const visible = boundInventory(full, ctx.cwd, recent);

      // A unique, private snapshot makes every checkpoint's archive immutable
      // across resume, forks, /tree navigation, and concurrent Pi processes.
      const sessionId = ctx.sessionManager.getSessionId().replace(/[^a-zA-Z0-9_-]/g, "_");
      const directory = join(ctx.sessionManager.getSessionDir(), "compaction-inventories", sessionId);
      await mkdir(directory, { recursive: true, mode: 0o700 });
      const archivePath = join(directory, `${randomUUID()}.json`);
      await writeFile(archivePath, JSON.stringify({
        version: 1,
        sessionId: ctx.sessionManager.getSessionId(),
        cwd: ctx.cwd,
        createdAt: new Date().toISOString(),
        reason: event.reason,
        ...full,
      }, null, 2) + "\n", { mode: 0o600, flag: "wx", signal });
      signal.throwIfAborted();

      const settings = pi.getSettings().retry;
      // Reuse Pi's boundary handling, split-turn summaries, validation and
      // retries. Route through the registry for current OAuth/provider auth.
      const result = await compact(
        {
          ...preparation,
          previousSummary: preparation.previousSummary
            ? stripInventories(preparation.previousSummary) || undefined
            : undefined,
          fileOps: {
            read: new Set(visible.readFiles),
            edited: new Set(visible.modifiedFiles),
            written: new Set(),
          },
        },
        ctx.model,
        undefined,
        undefined,
        [FOCUS, event.customInstructions].filter(Boolean).join("\n\n"),
        signal,
        ctx.thinkingLevel,
        (model, context, options) => ctx.modelRegistry.streamSimple(model, context, options),
        undefined,
        {
          enabled: settings?.enabled ?? true,
          maxRetries: settings?.maxRetries ?? 3,
          baseDelayMs: settings?.baseDelayMs ?? 2000,
          maxAgentDelayMs: settings?.maxAgentDelayMs ?? 60000,
        },
        undefined,
        randomUUID(),
      );
      signal.throwIfAborted();
      const narrative = stripInventories(result.summary);
      if (!narrative) throw new Error("Summary was empty; original context retained");
      const summary = [
        narrative,
        formatInventory(visible),
        `<file-inventory-archive>\nFile inventory above is bounded; paths are relative to ${ctx.cwd} unless absolute.\nFull historical file inventory: ${archivePath}\nRead selectively if needed; do not load the entire inventory by default.\n</file-inventory-archive>`,
      ].filter(Boolean).join("\n\n");

      return {
        compaction: {
          ...result,
          summary,
          // Full arrays are session metadata, NOT model context. The next hook
          // merges them explicitly: Pi skips fromHook inventories by design.
          details: { ...full, boundedInventory: { version: 1, archivePath, visible } },
        },
      };
    } catch (error) {
      if (!signal.aborted) {
        const message = error instanceof Error ? error.message : String(error);
        if (ctx.hasUI) ctx.ui.notify(`Bounded compaction failed: ${message}. Original context retained.`, "error");
        else console.error(`Bounded compaction failed: ${message}. Original context retained.`);
      }
      // Do not silently fall back to the unbounded implementation or persist
      // an incomplete checkpoint. Failed attempts may leave harmless archives.
      return { cancel: true };
    }
  });

  pi.registerCommand("compaction-inventory", {
    description: "Show the latest compaction's full file-inventory archive",
    handler: async (_args, ctx) => {
      const entry = [...ctx.sessionManager.getBranch()].reverse().find((item) => item.type === "compaction");
      const details = entry?.details as { boundedInventory?: { archivePath?: string } } | undefined;
      const inventory = inventoryFromDetails(entry?.details);
      const message = details?.boundedInventory?.archivePath
        ? `${inventory.readFiles.length} read-only / ${inventory.modifiedFiles.length} modified files. Archive: ${details.boundedInventory.archivePath}`
        : "No bounded-compaction archive yet. Run /compact after /reload.";
      if (ctx.hasUI) ctx.ui.notify(message, "info");
      else console.error(message);
    },
  });
}
