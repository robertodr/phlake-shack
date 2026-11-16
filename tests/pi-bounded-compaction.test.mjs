import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";
import {
  boundInventory,
  displayPath,
  formatInventory,
  inventoryFromDetails,
  inventoryFromMessages,
  inventoryFromSummary,
  MAX_INVENTORY_CHARS,
  MAX_INVENTORY_PATHS,
  mergeInventories,
  stripInventories,
} from "../homes/profiles/pi-coding-agent/bounded-compaction/inventory.ts";

const cwd = "/project";
const largeInventory = {
  readFiles: Array.from({ length: 704 }, (_, i) => `/other/worktree/${"artifact-".repeat(22)}${i}.md`),
  modifiedFiles: Array.from({ length: 655 }, (_, i) => `/project/${"nested/".repeat(30)}${i}.ts`),
};

test("strips inventory/archive blocks without removing narrative paths", () => {
  const text = "Keep /project/important.ts and its constraints.\n\n";
  assert.equal(stripInventories(text + formatInventory(largeInventory)
    + "\n<file-inventory-archive>old archive</file-inventory-archive>"), text.trim());
  assert.equal(stripInventories("ordinary <other>text</other>"), "ordinary <other>text</other>");
});

test("merges metadata safely and gives modifications precedence", () => {
  assert.deepEqual(inventoryFromDetails(null), { readFiles: [], modifiedFiles: [] });
  assert.deepEqual(inventoryFromDetails({ readFiles: ["a", null, 1], modifiedFiles: "bad" }),
    { readFiles: ["a"], modifiedFiles: [] });
  assert.deepEqual(mergeInventories(
    { readFiles: ["a", "b"], modifiedFiles: ["new"] },
    { readFiles: ["b", "c"], modifiedFiles: ["a", "new", "old"] },
  ), { readFiles: ["b", "c"], modifiedFiles: ["new", "a", "old"] });
});

test("legacy XML inventories can be recovered without metadata", () => {
  assert.deepEqual(inventoryFromSummary(formatInventory(largeInventory)), largeInventory);
});

test("bounds rendered inventory by path count AND characters", () => {
  const bounded = boundInventory(largeInventory, cwd);
  assert.ok(bounded.readFiles.length + bounded.modifiedFiles.length <= MAX_INVENTORY_PATHS);
  assert.ok(formatInventory(bounded).length <= MAX_INVENTORY_CHARS);
  assert.ok(bounded.modifiedFiles.length > 0);
  const short = boundInventory({ readFiles: Array.from({ length: 100 }, (_, i) => `f${i}`), modifiedFiles: [] }, cwd);
  assert.equal(short.readFiles.length, MAX_INVENTORY_PATHS);
});

test("keeps recent modifications first; skips oversized/ambiguous paths intact", () => {
  const bounded = boundInventory(mergeInventories(
    { readFiles: [], modifiedFiles: ["/project/current.ts", "x".repeat(7000), "line\nbreak"] },
    largeInventory,
  ), cwd);
  assert.equal(bounded.modifiedFiles[0], "current.ts");
  assert.ok(!formatInventory(bounded).includes("line\nbreak"));
  assert.ok(!bounded.modifiedFiles.includes("x".repeat(7000)));
});

test("recent reads outrank historical modifications and retain modified status", () => {
  const recent = { readFiles: ["/project/read-now.ts", largeInventory.modifiedFiles[500]], modifiedFiles: [] };
  const full = mergeInventories(recent, largeInventory);
  const visible = boundInventory(full, cwd, recent);
  assert.ok(visible.readFiles.includes("read-now.ts"));
  assert.equal(visible.modifiedFiles[0], displayPath(largeInventory.modifiedFiles[500], cwd));
});

test("extracts direct and nested calls in reverse chronology, ignoring omitted arguments", () => {
  assert.deepEqual(inventoryFromMessages([
    { role: "assistant", content: [{ type: "toolCall", name: "read", arguments: { path: "old" } }] },
    { role: "toolResult", nestedCalls: { calls: [
      { name: "edit", arguments: { path: "nested" } },
      { name: "write" },
      { name: "read", arguments: { path: "new" } },
    ] } },
  ]), { readFiles: ["new", "old"], modifiedFiles: ["nested"] });
});

test("only shortens paths inside the exact working directory", () => {
  assert.equal(displayPath("/project/src/a.ts", cwd), "src/a.ts");
  assert.equal(displayPath("/project-other/a.ts", cwd), "/project-other/a.ts");
  assert.equal(displayPath("/other/worktree/a.ts", cwd), "/other/worktree/a.ts");
  assert.equal(displayPath("relative.ts", cwd), "relative.ts");
});

// Optional standalone; the Nix check supplies this to exercise Pi's real loader
// and compaction implementation without network access or credentials.
const packageDir = process.env.PI_PACKAGE_DIR;
const sourceDir = resolve(fileURLToPath(new URL("../homes/profiles/pi-coding-agent/bounded-compaction/", import.meta.url)));
const integration = (name, fn) => test(name, { skip: !packageDir }, async (t) => {
  const { loadExtensions } = await import(pathToFileURL(join(packageDir, "dist/core/extensions/loader.js")));
  const loaded = await loadExtensions([join(sourceDir, "index.ts")], cwd);
  assert.deepEqual(loaded.errors, []);
  assert.equal(loaded.extensions.length, 1);
  loaded.runtime.getSettings = () => ({ retry: { enabled: false } });
  const extension = loaded.extensions[0];
  const handler = extension.handlers.get("session_before_compact")[0];
  const directory = await mkdtemp(join(tmpdir(), "pi-compaction-test-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const controller = new AbortController();
  const requests = [];
  const notifications = [];
  const usage = { input: 100, output: 20, reasoning: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 120,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } };
  const response = { role: "assistant", content: [{ type: "text", text: "## Goal\nContinue the current task." }],
    stopReason: "stop", usage, timestamp: Date.now() };
  const previousSummary = "## Goal\nContinue the current task.\n\n" + formatInventory(largeInventory);
  const previous = { type: "compaction", id: "old", summary: previousSummary, details: largeInventory };
  const event = {
    type: "session_before_compact", reason: "manual", willRetry: false,
    signal: controller.signal, branchEntries: [previous], customInstructions: "Preserve the rollback command.",
    preparation: {
      firstKeptEntryId: "kept", tokensBefore: 200000, isSplitTurn: false,
      previousSummary,
      messagesToSummarize: [{ role: "assistant", content: [{ type: "toolCall", id: "read1", name: "edit", arguments: { path: "/project/current.ts" } }] }],
      turnPrefixMessages: [],
      fileOps: { read: new Set(largeInventory.readFiles), edited: new Set(largeInventory.modifiedFiles), written: new Set() },
      settings: { enabled: true, keepRecentTokens: 8000, reserveTokens: 32768 },
    },
  };
  const ctx = {
    cwd, hasUI: true, thinkingLevel: "medium",
    model: { provider: "test", id: "mock", api: "openai-responses", name: "Mock", reasoning: false,
      contextWindow: 500000, maxTokens: 128000, input: ["text"], cost: usage.cost },
    sessionManager: { getSessionDir: () => directory, getSessionId: () => "test-session", getBranch: () => event.branchEntries },
    ui: { notify: (...args) => notifications.push(args) },
    modelRegistry: { streamSimple: (model, context, options) => {
      requests.push({ model, context, options });
      return { result: async () => response };
    } },
  };
  try {
    await fn({ handler, event, ctx, response, requests, notifications, controller, extension });
  } catch (error) {
    t.diagnostic(JSON.stringify(notifications));
    throw error;
  }
});

integration("real loader + summarizer: strips old inventories and archives full paths privately", async ({ handler, event, ctx, requests, extension }) => {
  const original = structuredClone(event.preparation);
  const { compaction } = await handler(event, ctx);
  assert.equal(compaction.firstKeptEntryId, "kept");
  assert.equal(compaction.tokensBefore, 200000);
  assert.equal(compaction.usage.totalTokens, 120);
  assert.deepEqual(event.preparation, original, "do not mutate Pi's preparation");
  assert.equal(requests.length, 1);
  const prompt = JSON.stringify(requests[0].context);
  assert.ok(prompt.includes("2,000–4,000"));
  assert.ok(prompt.includes("Preserve the rollback command"));
  assert.ok(!prompt.includes(largeInventory.readFiles[0]));
  assert.equal(requests[0].options.signal, event.signal);
  assert.equal(requests[0].options.cacheRetention, "none");
  assert.equal(requests[0].options.reasoning, undefined); // mock is not a reasoning model
  const visible = inventoryFromSummary(compaction.summary);
  assert.equal(visible.modifiedFiles[0], "current.ts");
  assert.ok(formatInventory(visible).length <= MAX_INVENTORY_CHARS);
  assert.ok(compaction.summary.length < 7500);
  const archive = compaction.details.boundedInventory.archivePath;
  const archived = JSON.parse(await readFile(archive, "utf8"));
  assert.equal(archived.readFiles.length, 704);
  assert.equal(archived.modifiedFiles.length, 656);
  assert.ok(archived.modifiedFiles.includes("/project/current.ts"));
  assert.equal((await stat(archive)).mode & 0o777, 0o600);
  assert.equal((await stat(resolve(archive, ".."))).mode & 0o777, 0o700);
  const { SessionManager } = await import(pathToFileURL(join(packageDir, "dist/core/session-manager.js")));
  const session = SessionManager.inMemory(cwd);
  const kept = session.appendMessage({ role: "user", content: "Continue", timestamp: Date.now() });
  session.appendCompaction(compaction.summary, kept, compaction.tokensBefore, compaction.details, true, compaction.usage);
  const modelContext = JSON.stringify(session.buildSessionProjection().messages);
  assert.ok(modelContext.includes(archive));
  assert.ok(!modelContext.includes(largeInventory.readFiles[500]), "full metadata must stay outside model context");
  event.branchEntries.push({ type: "compaction", details: compaction.details });
  await extension.commands.get("compaction-inventory").handler("", ctx);
});

integration("repeat compaction carries off-context metadata and creates distinct archives", async ({ handler, event, ctx, requests }) => {
  const first = (await handler(event, ctx)).compaction;
  event.branchEntries.push({ type: "compaction", fromHook: true, summary: first.summary, details: first.details });
  event.preparation.previousSummary = first.summary;
  event.preparation.fileOps = { read: new Set(), written: new Set(), edited: new Set() };
  const second = (await handler(event, ctx)).compaction;
  assert.deepEqual(second.details.readFiles, first.details.readFiles);
  assert.deepEqual(second.details.modifiedFiles, first.details.modifiedFiles);
  assert.notEqual(second.details.boundedInventory.archivePath, first.details.boundedInventory.archivePath);
  assert.ok(!JSON.stringify(requests[1].context).includes(first.details.boundedInventory.archivePath));
});

integration("split-turn compaction retains the original kept boundary", async ({ handler, event, ctx, requests }) => {
  event.preparation.isSplitTurn = true;
  event.preparation.turnPrefixMessages = [{ role: "user", content: "Finish the current edit", timestamp: Date.now() }];
  const { compaction } = await handler(event, ctx);
  assert.equal(requests.length, 2);
  assert.equal(compaction.firstKeptEntryId, "kept");
  assert.equal(compaction.usage.totalTokens, 240);
  assert.ok(compaction.summary.includes("Turn Context (split turn)"));
});

for (const stopReason of ["length", "error"]) {
  integration(`does not persist ${stopReason} responses or silently fall back`, async ({ handler, event, ctx, response, notifications, requests }) => {
    response.stopReason = stopReason;
    assert.deepEqual(await handler(event, ctx), { cancel: true });
    assert.equal(requests.length, 1);
    assert.equal(notifications.at(-1)[1], "error");
  });
}

integration("does not persist empty summaries", async ({ handler, event, ctx, response }) => {
  response.content = [];
  assert.deepEqual(await handler(event, ctx), { cancel: true });
});

integration("refuses to compact when the archive cannot be written", async ({ handler, event, ctx, requests, notifications }) => {
  ctx.sessionManager.getSessionDir = () => fileURLToPath(import.meta.url); // file, not a directory
  assert.deepEqual(await handler(event, ctx), { cancel: true });
  assert.equal(requests.length, 0);
  assert.equal(notifications.at(-1)[1], "error");
});

integration("honors cancellation while the summary is being generated", async ({ handler, event, ctx, controller, response, notifications }) => {
  ctx.modelRegistry.streamSimple = () => ({ result: async () => {
    controller.abort();
    return response;
  } });
  assert.deepEqual(await handler(event, ctx), { cancel: true });
  assert.equal(notifications.length, 0);
});

integration("branch navigation does not reuse an abandoned branch's inventory", async ({ handler, event, ctx }) => {
  await handler(event, ctx);
  event.branchEntries = [{ type: "compaction", details: { readFiles: ["/project/branch-b.ts"], modifiedFiles: [] } }];
  event.preparation.previousSummary = "Work on branch B";
  event.preparation.messagesToSummarize = [];
  event.preparation.fileOps = { read: new Set(), written: new Set(), edited: new Set() };
  const { compaction } = await handler(event, ctx);
  assert.deepEqual(compaction.details.readFiles, ["/project/branch-b.ts"]);
  assert.deepEqual(compaction.details.modifiedFiles, []);
});

integration("honors cancellation before making a request", async ({ handler, event, ctx, controller, requests, notifications }) => {
  controller.abort();
  assert.deepEqual(await handler(event, ctx), { cancel: true });
  assert.equal(requests.length, 0);
  assert.equal(notifications.length, 0);
});
