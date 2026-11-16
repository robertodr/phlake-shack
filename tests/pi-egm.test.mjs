import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { mkdtemp, mkdir, readFile, readdir, realpath, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { createRequire } from "node:module";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";
import { EgmEngine } from "../homes/profiles/pi-coding-agent/egm/engine.mjs";
import { delegate, rpc, validateContract, TOOLS, loadBackend } from "../homes/profiles/pi-coding-agent/egm/backend.mjs";
import { artifactPath, capture, inventory, registry, snapshotOperations } from "../homes/profiles/pi-coding-agent/egm/snapshots.mjs";
import { phaseConfig, reviewSequence, skillInvocation, SKILLS, PERSONAS, STANDARDS } from "../homes/profiles/pi-coding-agent/egm/protocol.mjs";

const adapter = resolve(fileURLToPath(new URL("../homes/profiles/pi-coding-agent/egm/", import.meta.url)));
const bundle = process.env.EGM_PACKAGE;
const host = process.env.PI_PACKAGE_DIR;
const api = {
  SUBAGENT_DELEGATION_REQUEST_EVENT: "prompt-template:subagent:request",
  SUBAGENT_DELEGATION_RESPONSE_EVENT: "prompt-template:subagent:response",
  SUBAGENT_DELEGATION_UPDATE_EVENT: "prompt-template:subagent:update",
  SUBAGENT_DELEGATION_CANCEL_EVENT: "prompt-template:subagent:cancel",
};
function bus() {
  const listeners = new Map();
  return {
    on(name, fn) { const set = listeners.get(name) ?? new Set(); set.add(fn); listeners.set(name, set); return () => set.delete(fn); },
    emit(name, data) { for (const fn of [...(listeners.get(name) ?? [])]) fn(data); },
    count() { return [...listeners.values()].reduce((total, set) => total + set.size, 0); },
  };
}
async function temporary(t) {
  const directory = await mkdtemp(join(tmpdir(), "pi-egm-test-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  return directory;
}
function contract(root, agent, digest = "digest") {
  return {
    version: 3, protocol: { packageVersion: "0.88.1" },
    agent: { name: agent, filePath: join(root, "reviewers", agent.replace(/^pi-egm\./, "") + ".md") },
    context: "fresh", systemPromptMode: "replace", inheritProjectContext: false, inheritGlobalContext: false, inheritSkills: false,
    skills: { requested: [], resolved: [], missing: [] }, intercomBridge: { mode: "off", active: false }, roots: {}, diagnostics: [],
    tools: { explicitAllowlist: true, effectiveAllowlist: TOOLS, fanoutAuthorized: false, effectiveMcpTools: [], mcp: [], internalTools: [], disableAmbientExtensions: true, configuredExtensions: [join(root, "adapter/reader.ts")], requiredExtensionIds: ["phlake-egm-reader"], runtimeExtensions: [], toolExtensionPaths: [] },
    launchContractDigest: digest,
  };
}
async function fixture(t) {
  const cwd = await temporary(t), root = join(cwd, "bundle");
  await mkdir(join(root, "reviewers"), { recursive: true });
  await mkdir(join(root, "adapter"));
  await mkdir(join(root, "resources/document_standards"), { recursive: true });
  await writeFile(join(root, "adapter/reader.ts"), "// test");
  for (const reviewer of [...Object.keys(PERSONAS), "goldfish-explorer"]) await writeFile(join(root, "reviewers", reviewer + ".md"), "test profile");
  for (const standard of STANDARDS) await writeFile(join(root, "resources/document_standards", standard + ".md"), "Test standard");
  const document = join(cwd, "design.md");
  await writeFile(document, "# Fixture\nA self-contained document.\n## Detailed Implementation Plan\nCreate the documented file.\n");
  await writeFile(join(cwd, "source.txt"), "export const approved = 1;\n");
  await writeFile(join(cwd, "AGENTS.md"), "PROJECT-SECRET-CANARY");
  const events = bus(), requests = [], digests = new Map(), responses = [];
  const pi = { events, getSettings: () => ({}) };
  const context = {
    hasUI: true, cwd, model: { provider: "test", id: "stub" }, scopedModels: [], isProjectTrusted: () => true,
    sessionManager: { getSessionId: () => "test-session", getSessionFile: () => undefined, getLeafId: () => undefined, getSessionDir: () => cwd },
    modelRegistry: { getAvailable: () => [], getAll: () => [] },
    ui: { confirm: async () => true, select: async (_question, choices) => choices[0] },
  };
  let disposed = 0;
  const backend = {
    ...api,
    registerRequiredChildExtensions: () => ({ dispose() { disposed++; } }),
    registerSubagentCapabilityCeiling: () => ({ dispose() { disposed++; } }),
    async resolveSubagentLaunchContract(input) {
      const digest = createHash("sha256").update(input.task).digest("hex");
      digests.set(input.requestId, digest);
      return { ok: true, contract: contract(root, input.agent, digest) };
    },
  };
  events.on("subagents:rpc:v1:request", request => events.emit(`subagents:rpc:v1:reply:${request.requestId}`, { version: 1, requestId: request.requestId, success: true, data: {} }));
  events.on(api.SUBAGENT_DELEGATION_REQUEST_EVENT, request => {
    const token = /EGM_SNAPSHOT=([a-f0-9-]{36})/.exec(request.task)[1];
    const snapshot = registry().get(token);
    requests.push({ ...request, snapshot: structuredClone(snapshot) });
    const operations = snapshotOperations(snapshot.entries, snapshot.cwd, snapshot.audit);
    operations.read({ path: document });
    events.emit(api.SUBAGENT_DELEGATION_RESPONSE_EVENT, { requestId: request.requestId, ownerRunId: request.ownerRunId, nodeId: request.nodeId, status: "completed", runId: randomUUID(), launchContractDigest: digests.get(request.requestId), result: { kind: "text", text: "## What this proposes\nA fixture.\n## How the existing system works, per this document\nSelf-contained.\nNo findings." }, usage: { cost: 0 }, ...responses.shift() });
  });
  const engine = new EgmEngine({ pi, root, backend: async () => backend });
  t.after(() => engine.dispose());
  return { cwd, root, document, engine, context, pi, requests, backend, responses, getDisposed: () => disposed };
}

test("explicit commands only; all upstream workflows and phase maps survive", () => {
  assert.equal(skillInvocation("please discuss EGM"), undefined);
  assert.equal(skillInvocation("/skill:egm-not-real"), undefined);
  for (const skill of SKILLS) assert.equal(skillInvocation(`/skill:${skill} doc.md`).skill, skill);
  assert.deepEqual(reviewSequence("interactive"), ["initial", "comprehension", "critic", "intermediate", "readiness"]);
  assert.deepEqual(reviewSequence("feature_spec"), ["initial", "comprehension", "critic", "intermediate"]);
  assert.deepEqual(reviewSequence("implementation"), ["readiness"]);
  assert.equal(phaseConfig("brainstorm").reviewers.length, 7);
  assert.equal(phaseConfig("comprehension").documentOnly, true);
  assert.throws(() => phaseConfig("critic", ["egm-style"]), /Fixed upstream/);
  assert.throws(() => phaseConfig("loop", ["egm-synthesizer"]), /leaf reviewers/);
  assert.throws(() => phaseConfig("loop", ["egm-style"], { "egm-style": "../../escape" }), /Unsupported/);
});

test("canonical inventories omit symlinks/hidden trees and bound full inputs", async t => {
  const cwd = await temporary(t);
  await mkdir(join(cwd, "refs")); await mkdir(join(cwd, "refs/.pi"));
  await writeFile(join(cwd, "refs/a.txt"), "approved");
  await writeFile(join(cwd, "refs/.pi/AGENTS.md"), "hidden");
  await symlink("/etc/passwd", join(cwd, "refs/escape"));
  assert.deepEqual(await inventory(["refs"], cwd), [join(cwd, "refs/a.txt")]);
  assert.deepEqual(await capture(await inventory(["refs"], cwd)), [{ path: join(cwd, "refs/a.txt"), text: "approved" }]);
  await writeFile(join(cwd, "big"), "x".repeat(1024 * 1024 + 1));
  await assert.rejects(capture([join(cwd, "big")]), /exceeds/);
  await writeFile(join(cwd, "binary"), Buffer.from([0, 255]));
  await assert.rejects(capture([join(cwd, "binary")]));
});

test("snapshot operations deny traversal and never access live files", () => {
  const audit = [];
  const operations = snapshotOperations([{ path: "/project/design.md", text: "first\nneedle\nlast" }], "/project", audit);
  assert.equal(operations.read({ path: "design.md", offset: 2, limit: 1 }), "2: needle");
  assert.match(operations.grep({ pattern: "needle" }), /design.md:2: needle/);
  assert.match(operations.find({ pattern: "design" }), /design.md/);
  assert.throws(() => operations.read({ path: "../secret" }), /outside/);
  assert.throws(() => operations.read({ path: "/etc/passwd" }), /outside/);
  assert.throws(() => operations.read({ path: "design.md", offset: -1 }), /Invalid/);
  assert.deepEqual(Object.keys(operations), TOOLS);
  assert.ok(audit.every(row => !row.path || row.path === "/project/design.md"));
});

test("artifact names and symlink directories cannot escape approved outputs", async t => {
  const cwd = await temporary(t);
  await assert.rejects(artifactPath(cwd, "../escape.md"));
  await assert.rejects(artifactPath(cwd, "run.sh"));
  await symlink(cwd, join(cwd, "alias"));
  await assert.rejects(artifactPath(join(cwd, "alias"), "report.md"), /redirected/);
});

test("review invocation alone starts no children; plan and launch denials pause", async t => {
  const f = await fixture(t);
  await f.engine.start("egm-review", "Step=interactive", f.cwd);
  assert.equal(f.requests.length, 0);
  f.context.ui.confirm = async () => false;
  assert.equal((await f.engine.plan({ document: f.document }, f.context)).status, "paused");
  assert.equal(f.requests.length, 0);
  f.context.ui.confirm = async () => true;
  await f.engine.plan({ document: f.document }, f.context);
  await assert.rejects(f.engine.review({ phase: "critic" }, f.context), /ordering/);
  f.context.ui.confirm = async () => false;
  assert.equal((await f.engine.review({ phase: "initial" }, f.context)).status, "paused");
  assert.equal(f.requests.length, 0);
});

test("complete deterministic stage routing: fresh distinct children, criteria, document-only comprehension, Stage 8 prior report", async t => {
  const f = await fixture(t);
  await f.engine.start("egm-review", "Step=uninterrupted", f.cwd);
  await f.engine.plan({ document: f.document, references: ["source.txt"] }, f.context);
  for (const phase of reviewSequence("uninterrupted")) {
    if (phase === "intermediate") await f.engine.save("zoom_out_report.md", "Approved earlier Stage 5 synthesis.");
    const result = await f.engine.review({ phase }, f.context);
    assert.equal(result.status, "completed", JSON.stringify(result));
    assert.ok(result.results.every(row => row.report.startsWith(f.engine.active.directory)));
    if (phase === "comprehension") {
      const request = f.requests.at(-1);
      assert.deepEqual(request.snapshot.entries.map(entry => entry.path), [f.document]);
      assert.ok(!JSON.stringify(request).includes("PROJECT-SECRET-CANARY"));
      assert.match(request.task, /complete paraphrase/);
    }
  }
  assert.equal(f.requests.length, 10);
  assert.equal(new Set(f.requests.map(request => request.requestId)).size, 10);
  assert.equal(new Set(f.requests.map(request => request.nodeId)).size, 10);
  assert.ok(f.requests.every(request => request.context === "fresh" && request.skill === false && request.intercomBridge.mode === "off" && !request.resume));
  assert.ok(f.requests.filter(request => request.nodeId.startsWith("intermediate")).every(request => request.snapshot.entries.some(entry => entry.path.endsWith("zoom_out_report.md"))));
  assert.ok(f.requests.filter(request => !request.nodeId.startsWith("intermediate")).every(request => request.snapshot.entries.every(entry => !entry.path.endsWith("zoom_out_report.md"))));
  assert.equal(registry().size, 0);
  assert.equal(f.getDisposed(), 10);
});

test("changed target requires a newly approved plan; unsupported settings/refinements fail before spawn", async t => {
  const f = await fixture(t);
  await f.engine.start("egm-review", "Step=6", f.cwd);
  await f.engine.plan({ document: f.document }, f.context);
  await writeFile(f.document, "Changed after approval");
  await assert.rejects(f.engine.review({ phase: "comprehension" }, f.context), /Document changed/);
  assert.equal(f.requests.length, 0);
});

test("failed reviewer retries once in a new child and never becomes a clean review", async t => {
  const f = await fixture(t);
  await f.engine.start("smoke", "", f.cwd);
  f.responses.push({ status: "failed", error: "offline fixture failure" }, { status: "failed", error: "again" });
  const result = await f.engine.review({ phase: "smoke", document: f.document }, f.context);
  assert.equal(result.status, "partial");
  assert.equal(result.results[0].status, "not run");
  assert.equal(f.requests.length, 2);
  assert.notEqual(f.requests[0].requestId, f.requests[1].requestId);
  assert.notEqual(f.requests[0].task, f.requests[1].task);
  assert.deepEqual(f.requests[0].snapshot.entries, f.requests[1].snapshot.entries);
  assert.equal(registry().size, 0);
  assert.equal(f.getDisposed(), 2);
  await assert.rejects(f.engine.review({ phase: "smoke", document: f.document }, f.context), /cap/);
});

test("digest mismatch, mutable permission overrides and refinement memory fail closed", async t => {
  const f = await fixture(t);
  await f.engine.start("smoke", "", f.cwd);
  f.responses.push({ launchContractDigest: "unexpected" });
  assert.equal((await f.engine.review({ phase: "smoke", document: f.document }, f.context)).status, "partial");
  assert.equal(f.requests.length, 1);
  await assert.rejects(f.engine.review({ phase: "smoke", document: f.document }, f.context), /stopped/);
  await assert.rejects(f.engine.start("smoke", "", f.cwd), /Inspect the failed runtime/);
  f.engine.dispose();
  await f.engine.start("smoke", "", f.cwd);
  f.pi.getSettings = () => ({ subagents: { agentOverrides: { "pi-egm.egm-comprehension": { memory: "unsafe" } } } });
  await assert.rejects(f.engine.review({ phase: "smoke", document: f.document }, f.context), /mutable overrides/);
  f.pi.getSettings = () => ({ subagents: { watchdog: { children: { enabled: true } } } });
  await f.engine.start("smoke", "", f.cwd);
  await assert.rejects(f.engine.review({ phase: "smoke", document: f.document }, f.context), /Child watchdogs/);
  f.pi.getSettings = () => ({});
  await f.engine.start("smoke", "", f.cwd);
  await mkdir(join(f.cwd, ".pi/subagents/refinements"), { recursive: true });
  await writeFile(join(f.cwd, ".pi/subagents/refinements/pi-egm.egm-comprehension.md"), "EARLIER-REVIEW-CANARY");
  await assert.rejects(f.engine.review({ phase: "smoke", document: f.document }, f.context), /refinement overlay/);
  assert.equal(f.requests.length, 1);
});

test("successful reviewers require distinct runtime run identities, not just distinct request IDs", async t => {
  const f = await fixture(t);
  await f.engine.start("egm-review", "Step=5", f.cwd);
  await f.engine.plan({ document: f.document }, f.context);
  f.responses.push({ runId: "reused-runtime-id" }, { runId: "reused-runtime-id" });
  const result = await f.engine.review({ phase: "initial" }, f.context);
  assert.equal(result.status, "partial");
  assert.ok(result.results.some(row => row.error?.includes("reused run identity")));
  assert.equal(f.engine.active.poisoned, true);
  const missing = await fixture(t);
  await missing.engine.start("smoke", "", missing.cwd);
  missing.responses.push({ runId: undefined });
  assert.equal((await missing.engine.review({ phase: "smoke", document: missing.document }, missing.context)).status, "partial");
  assert.equal(missing.engine.active.poisoned, true);
});

test("saveDocument cannot edit code, instructions, outside files or symlink targets", async t => {
  const f = await fixture(t);
  await f.engine.start("egm-draft", "", f.cwd);
  for (const path of ["main.py", "AGENTS.md", "../outside.md", ".pi/steering.md"]) await assert.rejects(f.engine.saveDocument(path, "text", f.context), /ordinary project Markdown/);
  await symlink(f.document, join(f.cwd, "alias.md"));
  await assert.rejects(f.engine.saveDocument("alias.md", "text", f.context), /symlink/);
  f.context.ui.confirm = async () => false;
  assert.equal((await f.engine.saveDocument("design.md", "replacement", f.context)).status, "paused");
  assert.match(await readFile(f.document, "utf8"), /self-contained/);
  f.context.ui.confirm = async () => true;
  assert.equal((await f.engine.saveDocument("docs/designs/approved.md", "Approved document", f.context)).status, "saved");
  assert.equal(await readFile(join(f.cwd, "docs/designs/approved.md"), "utf8"), "Approved document");
  f.context.ui.confirm = async () => { await writeFile(f.document, "Operator's concurrent change"); return true; };
  await assert.rejects(f.engine.saveDocument("design.md", "Stale replacement", f.context), /changed while awaiting approval/);
  assert.equal(await readFile(f.document, "utf8"), "Operator's concurrent change");
});

test("launch contract rejects widened tools, context, inherited instructions, ambient extensions and shadowed profiles", async t => {
  const f = await fixture(t), agent = "pi-egm.egm-comprehension";
  const options = { agent, reader: join(f.root, "adapter/reader.ts"), profile: join(f.root, "reviewers/egm-comprehension.md") };
  const base = contract(f.root, agent);
  await validateContract(base, options);
  for (const change of [
    value => { value.context = "fork"; }, value => { value.inheritProjectContext = true; },
    value => { value.inheritGlobalContext = true; }, value => { value.inheritSkills = true; },
    value => { value.tools.effectiveAllowlist.push("bash"); }, value => { value.tools.configuredExtensions.push("evil.ts"); },
    value => { value.tools.disableAmbientExtensions = false; }, value => { value.tools.requiredExtensionIds.push("unexpected"); },
    value => { value.agent.filePath = f.document; }, value => { value.skills.resolved.push({ name: "ambient" }); },
  ]) {
    const value = structuredClone(base); change(value);
    await assert.rejects(validateContract(value, options), /widened|shadowed/);
  }
});

test("RPC missing readiness times out without dispatch; correlation ignores unrelated replies", async () => {
  const events = bus(), pi = { events };
  await assert.rejects(rpc(pi, "ping", {}, 5), /not ready/);
  assert.equal(events.count(), 0);
  events.on("subagents:rpc:v1:request", request => {
    events.emit(`subagents:rpc:v1:reply:${request.requestId}`, { version: 1, requestId: "wrong", success: true });
    events.emit(`subagents:rpc:v1:reply:${request.requestId}`, { version: 1, requestId: request.requestId, success: true, data: "ready" });
  });
  assert.equal(await rpc(pi, "ping"), "ready");
});

test("structured cancellation uses exact attempt identity and disposes listeners", async () => {
  const events = bus(), pi = { events }, controller = new AbortController();
  const request = { requestId: "request", ownerRunId: "owner", nodeId: "node", timeoutMs: 1000 };
  events.on(api.SUBAGENT_DELEGATION_CANCEL_EVENT, identity => {
    assert.deepEqual(identity, { requestId: "request", ownerRunId: "owner", nodeId: "node" });
    events.emit(api.SUBAGENT_DELEGATION_RESPONSE_EVENT, { ...identity, status: "cancelled" });
  });
  const pending = delegate(pi, api, request, controller.signal, undefined, 5);
  events.emit(api.SUBAGENT_DELEGATION_RESPONSE_EVENT, { ...request, nodeId: "foreign", status: "completed" });
  controller.abort();
  assert.equal((await pending).status, "cancelled");
  assert.equal(events.count(), 1);
  const missing = bus(), abort = new AbortController();
  const unacknowledged = delegate({ events: missing }, api, request, abort.signal, undefined, 5);
  abort.abort();
  await assert.rejects(unacknowledged, /unacknowledged/);
  assert.equal(missing.count(), 0);
});

test("installed bundle preserves source layout, license, seven nonautomatic skills and generated persona bodies", { skip: !bundle }, async () => {
  assert.equal((await readFile(join(bundle, "REVISION"), "utf8")).trim(), "72d06f52a2482885d9a64bd24b291c6e8628942c");
  assert.match(await readFile(join(bundle, "LICENSE"), "utf8"), /Apache License/);
  for (const skill of SKILLS) {
    const file = join(bundle, "skills", skill, "SKILL.md");
    assert.match(await readFile(file, "utf8"), /disable-model-invocation: true/);
    assert.equal(await realpath(resolve(dirname(file), "../../agents")), join(bundle, "agents"));
    assert.equal(await realpath(resolve(dirname(file), "../../resources")), join(bundle, "resources"));
    assert.equal(await realpath(resolve(dirname(file), "../../docs")), join(bundle, "docs"));
  }
  for (const [reviewer, source] of Object.entries(PERSONAS)) {
    const original = (await readFile(join(bundle, "agents", `${source}.md`), "utf8")).split("---").slice(2).join("---");
    const generated = await readFile(join(bundle, "reviewers", reviewer + ".md"), "utf8");
    assert.equal(generated.split("---").slice(2).join("---"), original);
    for (const field of ["inheritProjectContext", "inheritGlobalContext", "inheritSkills"]) assert.match(generated, new RegExp(`${field}: false`));
    assert.match(generated, /defaultContext: "fresh"/);
    assert.match(generated, /tools: "read, grep, find, ls"/);
  }
  assert.equal((await readdir(join(bundle, "reviewers"))).length, 9);
});

test("real Pi resource discovery through a Home Manager-style store symlink", { skip: !bundle || !host }, async t => {
  const cwd = await temporary(t), agentDir = join(cwd, "agent");
  await mkdir(agentDir);
  const link = join(agentDir, "egm"); await symlink(bundle, link);
  const previousHome = process.env.HOME;
  process.env.HOME = cwd;
  t.after(() => { process.env.HOME = previousHome; });
  const sdk = await import(pathToFileURL(join(host, "dist/index.js")));
  const loader = new sdk.DefaultResourceLoader({ cwd, agentDir, settingsManager: sdk.SettingsManager.inMemory({ packages: [link] }), noContextFiles: true });
  await loader.reload();
  assert.deepEqual(loader.getExtensions().errors, []);
  assert.equal(loader.getExtensions().extensions.length, 1);
  const found = loader.getSkills();
  assert.deepEqual(found.diagnostics, []);
  assert.deepEqual(found.skills.map(skill => skill.name).sort(), [...SKILLS].sort());
  for (const skill of found.skills) { assert.equal(skill.disableModelInvocation, true); assert.ok((await realpath(skill.filePath)).startsWith(bundle)); }
  await loader.reload();
  assert.deepEqual(loader.getExtensions().errors, []);
});

test("real loaded reviewer tool implementation denies mutation and outside reads; document canary remains unchanged", { skip: !bundle || !host }, async t => {
  const cwd = await temporary(t), token = randomUUID();
  const path = join(cwd, "canary.md");
  await writeFile(path, "ORIGINAL-CANARY");
  const hostRequire = createRequire(join(host, "package.json"));
  const { createJiti } = hostRequire("jiti");
  const resolver = createJiti(join(host, "package.json"));
  const peers = ["@earendil-works/pi-coding-agent", "typebox"];
  const loader = createJiti(join(host, "package.json"), { alias: Object.fromEntries(peers.map(name => [name, resolver.esmResolve(name)])), nativeModules: peers });
  const factory = await loader.import(join(bundle, "adapter/reader.ts"), { default: true });
  const tools = new Map(), handlers = new Map();
  let selected;
  factory({ registerTool(tool) { tools.set(tool.name, tool); }, on(name, handler) { handlers.set(name, handler); }, setActiveTools(names) { selected = names; } });
  assert.deepEqual([...tools.keys()], TOOLS);
  registry().set(token, { entries: [{ path, text: "ORIGINAL-CANARY" }], cwd, audit: [] });
  t.after(() => registry().delete(token));
  await handlers.get("before_agent_start")({ prompt: `EGM_SNAPSHOT=${token}` });
  assert.deepEqual(selected, TOOLS);
  assert.match((await tools.get("read").execute("read-test", { path })).content[0].text, /ORIGINAL-CANARY/);
  await assert.rejects(tools.get("read").execute("escape", { path: "/etc/passwd" }), /outside/);
  for (const toolName of ["bash", "write", "edit", "codemode", "subagent", "mcp__server__read"]) {
    assert.equal(tools.has(toolName), false);
    assert.equal((await handlers.get("tool_call")({ toolName })).block, true);
  }
  await handlers.get("session_shutdown")();
  await assert.rejects(tools.get("read").execute("disposed", { path }), /No authorized/);
  assert.equal(await readFile(path, "utf8"), "ORIGINAL-CANARY");
});

test("loaded parent adapter activates only on explicit invocation and restores ordinary tool scope on exit", { skip: !bundle || !host }, async t => {
  const cwd = await temporary(t);
  const hostRequire = createRequire(join(host, "package.json"));
  const { createJiti } = hostRequire("jiti");
  const resolver = createJiti(join(host, "package.json"));
  const peers = ["@earendil-works/pi-coding-agent", "@earendil-works/pi-agent-core", "@earendil-works/pi-ai", "@earendil-works/pi-tui", "typebox", "typebox/compile", "typebox/value"];
  const loader = createJiti(join(host, "package.json"), { alias: Object.fromEntries(peers.map(name => [name, resolver.esmResolve(name)])), nativeModules: peers });
  const factory = await loader.import(join(bundle, "adapter/index.ts"), { default: true });
  const handlers = new Map(), commands = new Map(), tools = new Map();
  const original = ["read", "bash", "write", "edit", "codemode"];
  let active = [...original];
  await factory({ events: bus(), on(name, fn) { handlers.set(name, fn); }, registerCommand(name, command) { commands.set(name, command); }, registerTool(tool) { tools.set(tool.name, tool); }, getActiveTools() { return active; }, setActiveTools(names) { active = [...names]; }, sendMessage() {} });
  const context = { cwd, hasUI: true, ui: { notify() {} } };
  const before = { systemPromptOptions: { sections: {} } };
  handlers.get("before_agent_start")(before);
  assert.deepEqual(before.systemPromptOptions.sections, {});
  assert.equal(handlers.get("tool_call")({ toolName: "bash" }), undefined);
  assert.equal((await handlers.get("input")({ text: "/skill:egm-review design.md", source: "extension" }, context)).action, "handled");
  assert.deepEqual(active, original);
  const invocation = await handlers.get("input")({ text: "/skill:egm-review design.md", source: "interactive" }, context);
  assert.equal(invocation.action, "transform");
  assert.match(invocation.text, /five review phases/);
  for (const name of TOOLS) assert.ok(active.includes(name));
  assert.equal(handlers.get("tool_call")({ toolName: "bash" }).block, true);
  assert.equal(handlers.get("tool_call")({ toolName: "write" }).block, true);
  assert.equal(handlers.get("tool_call")({ toolName: "read" }), undefined);
  for (const tool of tools.values()) { assert.equal(tool.exposure, "model-only"); assert.equal(tool.defaultActive, false); }
  await commands.get("egm-exit").handler("", context);
  assert.deepEqual(active, original);
  assert.equal(handlers.get("tool_call")({ toolName: "bash" }), undefined);
  assert.equal(handlers.get("tool_call")({ toolName: "egm_reviewers" }).block, true);
  await handlers.get("session_shutdown")();
});

// Opt-in OFFLINE API check: no child/model dispatch and no live settings edits.
// A mutable installed runtime cannot be captured in a hermetic Nix sandbox.
test("installed pi-subagents public exports resolve from store glue and preflight actual generated profiles", { skip: !bundle || !host || !process.env.PI_SUBAGENTS_PACKAGE }, async t => {
  const cwd = await temporary(t), agentDir = join(cwd, "agent");
  await mkdir(join(agentDir, "npm/node_modules"), { recursive: true });
  await symlink(process.env.PI_SUBAGENTS_PACKAGE, join(agentDir, "npm/node_modules/pi-subagents"));
  await writeFile(join(agentDir, "settings.json"), JSON.stringify({ packages: [bundle] }));
  const before = process.env.PI_CODING_AGENT_DIR;
  process.env.PI_CODING_AGENT_DIR = agentDir;
  t.after(() => { if (before === undefined) delete process.env.PI_CODING_AGENT_DIR; else process.env.PI_CODING_AGENT_DIR = before; });
  const sdk = await import(pathToFileURL(join(host, "dist/index.js")));
  const backend = await loadBackend({ agentDir, packageDir: host, version: sdk.VERSION, SessionManager: sdk.SessionManager });
  const sessionId = randomUUID(), reader = join(bundle, "adapter/reader.ts");
  const required = backend.registerRequiredChildExtensions({ sessionId, extensions: [{ id: "phlake-egm-reader", path: reader }], requireForAllRunners: true });
  t.after(() => required.dispose());
  await assert.rejects(loadBackend({ agentDir, packageDir: host, version: "unsupported", SessionManager: sdk.SessionManager }), /audited Pi/);
  for (const reviewer of [...Object.keys(PERSONAS), "goldfish-explorer"]) {
    const agent = `pi-egm.${reviewer}`;
    const result = await backend.resolveSubagentLaunchContract({ agent, cwd, task: "OFFLINE PREFLIGHT ONLY", context: "fresh", skill: false, parentSessionId: sessionId, sessionRoot: cwd, availableModels: [], intercomBridge: { mode: "off" } });
    assert.equal(result.ok, true, JSON.stringify(result));
    await validateContract(result.contract, { agent, reader, profile: join(bundle, "reviewers", reviewer + ".md"), runtimeExtensions: backend.runtimeExtensions }).catch(error => { throw new Error(JSON.stringify(result.contract, null, 2), { cause: error }); });
  }
  // The real bundled CLI has a different SDK identity from adjacent dist/index.js.
  // Exercise its mapped live exports with a command that makes no model request.
  await writeFile(join(agentDir, "settings.json"), JSON.stringify({ packages: [process.env.PI_SUBAGENTS_PACKAGE, bundle], defaultProvider: "openai", defaultModel: "offline-no-model" }));
  const pendingDiagnostic = promisify(execFile)(process.execPath, [join(host, "dist/bundle/cli.js"), "--no-session", "--no-skills", "--no-prompt-templates", "--no-context-files", "-p", "/egm-doctor"], {
    cwd, timeout: 30000,
    env: { PATH: process.env.PATH, HOME: cwd, PI_CODING_AGENT_DIR: agentDir, PI_SUBAGENTS_TEMP_ROOT: join(cwd, "runtime-state"), PI_SKIP_VERSION_CHECK: "1", PI_TELEMETRY: "0" },
  });
  pendingDiagnostic.child.stdin.end();
  const diagnostic = await pendingDiagnostic;
  assert.match(diagnostic.stderr, /EGM offline doctor:.*passed/);
  assert.ok(!diagnostic.stderr.includes("Extension error"));
});
