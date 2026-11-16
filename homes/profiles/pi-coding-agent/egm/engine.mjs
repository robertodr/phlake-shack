import { createHash, randomUUID } from "node:crypto";
import { mkdir, realpath, rename, rm, writeFile, lstat } from "node:fs/promises";
import { basename, dirname, join, relative, resolve } from "node:path";
import { artifactPath, boundedText, capture, inside, inventory, registry, MAX_BYTES, MAX_FILES } from "./snapshots.mjs";
import { COMPATIBILITY, TOOLS, delegate, rpc, validateContract } from "./backend.mjs";
import { PERSONAS, phaseConfig, reviewSequence } from "./protocol.mjs";

export class EgmEngine {
  constructor({ pi, root, backend, mutate = (_path, action) => action() }) {
    this.pi = pi; this.root = root; this.backend = backend; this.mutate = mutate;
    this.active = undefined;
    this.controllers = new Set();
    this.busy = false;
  }
  async start(skill, args, cwd) {
    if (this.busy) throw new Error("Stop the active reviewers before starting another workflow");
    if (this.active?.poisoned) throw new Error("Inspect the failed runtime, then explicitly /egm-exit before starting another workflow");
    const base = await realpath(cwd);
    const id = randomUUID();
    const directory = join(base, ".dev", "egm", id);
    // Never follow a pre-existing .dev/egm symlink while creating outputs.
    for (const path of [join(base, ".dev"), join(base, ".dev", "egm")]) {
      try { if ((await lstat(path)).isSymbolicLink()) throw new Error("EGM output ancestor is a symlink"); }
      catch (error) { if (error.code !== "ENOENT") throw error; }
    }
    await mkdir(directory, { recursive: true, mode: 0o700 });
    this.active = { id, skill, args, cwd: base, directory: await realpath(directory), launches: 0, rounds: {}, sequence: undefined, completed: 0 };
    return this.active;
  }
  requireActive() {
    if (!this.active) throw new Error("Invoke an EGM skill explicitly before using EGM tools");
    if (this.active.poisoned) throw new Error("EGM is stopped after an uncertain/security failure; inspect the runtime before a new invocation");
    return this.active;
  }
  dispose() {
    for (const controller of this.controllers) controller.abort();
    this.active = undefined;
  }
  async save(name, content) {
    const active = this.requireActive();
    boundedText(content);
    const path = await artifactPath(active.directory, name);
    return this.mutate(path, async () => {
      const temp = join(active.directory, `${randomUUID()}.tmp`);
      try {
        await writeFile(temp, content, { flag: "wx", mode: 0o600 });
        await artifactPath(active.directory, name);
        await rename(temp, path); // Replaces a symlink itself, never its target.
      } finally { await rm(temp, { force: true }); }
      return path;
    });
  }
  async saveDocument(path, content, ctx) {
    const active = this.requireActive();
    boundedText(content);
    if (!ctx.hasUI) throw new Error("Document edits need interactive approval; save an artifact instead");
    boundedText(path, 4096);
    if (/[\x00-\x1f\x7f]/.test(path)) throw new Error("Document path contains control characters");
    const target = resolve(active.cwd, path);
    if (!inside(active.cwd, target) || !target.endsWith(".md") || /^(AGENTS|CLAUDE|GEMINI|WATCHDOG|SKILL)\.md$/i.test(basename(target))
        || relative(active.cwd, target).split("/").some(part => part.startsWith("."))) throw new Error("Only ordinary project Markdown documents may be edited");
    const parent = dirname(target);
    let existing = parent;
    while (true) {
      try { if (await realpath(existing) !== existing) throw new Error("Document parent contains a symlink"); break; }
      catch (error) { if (error.code !== "ENOENT") throw error; existing = dirname(existing); }
    }
    let original;
    try {
      if ((await lstat(target)).isSymbolicLink()) throw new Error("Document is a symlink");
      original = (await capture([target]))[0].text;
    } catch (error) { if (error.code !== "ENOENT") throw error; }
    const proposal = await this.save(`proposed-${randomUUID()}.md`, content);
    if (!await ctx.ui.confirm("Apply EGM document update?", `Only ${target}\nReview the exact proposed contents in ${proposal}. No code changes are authorized.`, { timeout: 60000 })) {
      return { status: "paused", proposal };
    }
    return this.mutate(target, async () => {
      const temporary = join(parent, `egm-${randomUUID()}.tmp`);
      try {
        await mkdir(parent, { recursive: true });
        if (await realpath(parent) !== parent) throw new Error("Document parent was redirected");
        let current;
        try { current = (await capture([target]))[0].text; }
        catch (error) { if (error.code !== "ENOENT") throw error; }
        if (current !== original) throw new Error("Document changed while awaiting approval; propose the update again");
        await writeFile(temporary, content, { flag: "wx", mode: 0o600 });
        await rename(temporary, target);
      } finally { await rm(temporary, { force: true }); }
      return { status: "saved", path: target, proposal };
    });
  }
  async plan(params, ctx) {
    const active = this.requireActive();
    if (active.skill !== "egm-review") throw new Error("Review plans belong to egm-review");
    if (!ctx.hasUI) throw new Error("Review configuration requires a human approval surface");
    let preset = /(?:Step\s*[:=]\s*|--step[= ])(interactive|uninterrupted|feature_spec|implementation|[5-9])\b/i.exec(active.args)?.[1]?.toLowerCase();
    if (!preset) {
      const choices = [
        "Interactive review with all review rubrics (step-by-step, check in after each review)",
        "Consolidated report with all review rubrics (runs full flow without stopping)",
        "Feature spec only (evaluate design without considering implementation)",
        "Implementation plan only (evaluate design for implementation readiness)",
      ];
      const choice = await ctx.ui.select("Select the review execution mode for this document:", choices, { timeout: 60000 });
      if (!choice) return { status: "paused" };
      preset = ["interactive", "uninterrupted", "feature_spec", "implementation"][choices.indexOf(choice)];
    }
    const document = await realpath(resolve(active.cwd, params.document));
    const [{ text }] = await capture([document]);
    const lines = text.split("\n");
    const candidates = lines.flatMap((line, i) => /^## (Detailed Implementation Plan|Implementation Plan|Work Breakdown|Implementation Steps)\s*$/i.test(line) ? [i + 1] : []);
    let split = preset === "feature_spec" ? undefined : params.splitLine ?? (candidates.length === 1 ? candidates[0] : undefined);
    if (split !== undefined && (!Number.isSafeInteger(split) || split < 2 || split > lines.length)) throw new Error("Invalid semantic split");
    if (candidates.length > 1 && params.splitLine === undefined && preset !== "feature_spec") throw new Error("Ambiguous split; ask the author for splitLine before review");
    let sequence = reviewSequence(preset);
    if (!split && sequence.includes("readiness")) {
      if (preset === "implementation" || preset === "9") throw new Error("No implementation plan found; ask the author for its boundary");
      sequence = sequence.filter(phase => phase !== "readiness");
    }
    const references = await inventory(params.references ?? [], active.cwd);
    const initialReport = params.initialReport ?? "zoom_out_report.md";
    await artifactPath(active.directory, initialReport);
    if (!await ctx.ui.confirm("Approve EGM review plan?", JSON.stringify({ document, preset, sequence, featureRange: [1, split ? split - 1 : lines.length], detailedRange: split ? [split, lines.length] : null, references, initialReportForStage8: initialReport, limits: "120 attempts, 8 concurrent, 5 rounds per phase, 5 minutes per child; read-only snapshots; provider usage may cost money" }, null, 2), { timeout: 60000 })) return { status: "paused" };
    const sameFlow = active.plan?.document === document && JSON.stringify(active.sequence) === JSON.stringify(sequence);
    active.plan = { document, documentDigest: createHash("sha256").update(text).digest("hex"), split, references, preset, initialReport };
    active.sequence = sequence;
    if (!sameFlow) active.completed = 0;
    return { status: "configured", ...active.plan, sequence };
  }
  async review(params, ctx, signal, onUpdate) {
    const active = this.requireActive();
    if (this.busy) throw new Error("An EGM batch is already active");
    if (!ctx.hasUI) throw new Error("Live reviewers require an interactive approval surface");
    const config = phaseConfig(params.phase, params.reviewers, params.standards);
    if (active.skill === "egm-review") {
      if (!active.plan) throw new Error("Configure and approve the full review plan first");
      const expected = active.sequence[active.completed];
      const previous = active.sequence[active.completed - 1];
      if (params.phase !== expected && params.phase !== previous) throw new Error(`Upstream stage ordering requires ${expected ?? "completion"}`);
      if (params.document || params.references || params.startLine || params.endLine) throw new Error("Use the approved plan's document, ranges and reading list");
    } else {
      const allowed = { "egm-brainstorm": ["brainstorm"], "egm-review-loop": ["loop"], "egm-bootstrap": ["bootstrap"], smoke: ["smoke"] };
      if (!allowed[active.skill]?.includes(params.phase)) throw new Error("This workflow does not authorize that reviewer phase");
    }
    const round = (active.rounds[params.phase] ?? 0) + 1;
    const cap = params.phase === "smoke" ? 1 : ["initial", "comprehension", "intermediate"].includes(params.phase) ? 2 : 5;
    if (round > cap || active.launches + config.reviewers.length * 2 > 120) throw new Error("EGM round/fanout cap reached; stop and ask the operator");
    const document = active.plan?.document ?? await realpath(resolve(active.cwd, params.document));
    const referenceFiles = config.documentOnly ? [] : [...(active.plan?.references ?? await inventory(params.references ?? [], active.cwd))];
    if (params.phase === "intermediate") referenceFiles.push(await artifactPath(active.directory, active.plan.initialReport));
    if (config.documentOnly && params.references?.length) throw new Error("Document-only phases cannot receive references");
    const files = [...new Set([document, ...referenceFiles])];
    const criteria = params.criteria ? boundedText(params.criteria, 4000) : "";
    // Every batch is a concrete authorization boundary. Uninterrupted means no
    // editorial stage checkpoints, not silent permission to spend model quota.
    if (!await ctx.ui.confirm("Launch fresh EGM reviewers?", JSON.stringify({ phase: params.phase, round, reviewers: config.reviewers, document, approvedReferences: referenceFiles, criteria, limits: "Up to two fresh attempts per reviewer; 8 concurrent; 5 minutes per child. No filesystem tools beyond the approved snapshot. This consumes your configured model quota." }, null, 2), { timeout: 60000 })) return { status: "paused", reviewers: [] };
    signal?.throwIfAborted();
    if (this.busy || this.active !== active) throw new Error("Workflow changed while waiting for approval");
    this.busy = true;
    active.rounds[params.phase] = round;
    const controller = new AbortController();
    const abort = () => controller.abort();
    signal?.addEventListener("abort", abort, { once: true });
    this.controllers.add(controller);
    let required, ceiling;
    try {
      const api = await this.backend();
      const settings = this.pi.getSettings();
      const runtimeSettings = await api.inspectRuntimeSettings?.() ?? {};
      for (const watchdog of [settings.subagents?.watchdog, runtimeSettings.watchdog]) {
        if (watchdog?.children?.enabled || Object.values(watchdog?.children?.overrides ?? {}).some(value => value.enabled)) {
          throw new Error("Child watchdogs are not audited for EGM isolation; disable them explicitly before review");
        }
      }
      await rpc(this.pi, "ping");
      const entries = await capture(files);
      const documentText = entries.find(entry => entry.path === document).text;
      if (active.plan && createHash("sha256").update(documentText).digest("hex") !== active.plan.documentDigest) throw new Error("Document changed; re-read it and obtain an updated review plan/split before proceeding");
      const lines = documentText.split("\n").length;
      let start = params.startLine ?? 1, end = params.endLine ?? lines;
      if (active.plan) {
        if (params.phase === "critic") end = active.plan.split ? active.plan.split - 1 : lines;
        if (params.phase === "readiness") start = active.plan.split;
      }
      if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start < 1 || end < start || end > lines) throw new Error("Invalid or stale document line range; recalculate the semantic split");
      // Never honor prompt/permission/memory overrides from mutable settings.
      const overrides = settings.subagents?.agentOverrides ?? {};
      for (const reviewer of config.reviewers) {
        const values = overrides[`pi-egm.${reviewer}`] ?? {};
        if (Object.keys(values).some(key => !["model", "defaultProvider", "thinking", "fast"].includes(key))) throw new Error("EGM profile has unsupported mutable overrides");
        // Refinements are another persisted prompt input, separate from agent
        // settings. Refuse them rather than injecting a previous review's memory.
        for (let directory = active.cwd; ; directory = dirname(directory)) {
          for (const configDir of [".pi", ".agents"]) {
            try {
              await lstat(join(directory, configDir, "subagents", "refinements", `pi-egm.${reviewer}.md`));
              throw new Error("EGM reviewer has a project refinement overlay; remove it explicitly before review");
            } catch (error) { if (error.code !== "ENOENT") throw error; }
          }
          if (dirname(directory) === directory) break;
        }
      }
      const agents = config.reviewers.map(name => `pi-egm.${name}`);
      const reader = await realpath(join(this.root, "adapter", "reader.ts"));
      const sessionId = ctx.sessionManager.getSessionId();
      required = api.registerRequiredChildExtensions({ sessionId, extensions: [{ id: "phlake-egm-reader", path: reader }], requireForAllRunners: true });
      ceiling = api.registerSubagentCapabilityCeiling({ sessionId, source: "phlake-egm", ceiling: { allowedAgents: agents, allowedTools: TOOLS } });
      const results = await Promise.all(config.reviewers.map(async reviewer => {
        const standard = config.standards?.[reviewer];
        const standardEntries = standard ? await capture([join(this.root, "resources", "document_standards", `${standard}.md`)]) : [];
        const childEntries = [...entries, ...standardEntries];
        if (childEntries.length > MAX_FILES || childEntries.reduce((total, entry) => total + Buffer.byteLength(entry.text), 0) > MAX_BYTES) throw new Error("Snapshot plus standard exceeds the input limits; narrow the reading list");
        for (let attempt = 1; attempt <= 2; attempt++) {
          controller.signal.throwIfAborted();
          const token = randomUUID();
          const nodeId = `${params.phase}-${round}-${reviewer}-${attempt}`;
          const agent = `pi-egm.${reviewer}`;
          const audit = [];
          registry().set(token, { entries: childEntries, cwd: active.cwd, audit });
          const request = {
            requestId: randomUUID(), ownerRunId: active.id, nodeId, agent,
            context: "fresh", cwd: active.cwd, skill: false, timeoutMs: 300000,
            intercomBridge: { mode: "off" }, toolBudget: { hard: 64, block: "*" },
            result: { kind: "text" }, artifacts: true,
            task: [
              `EGM_SNAPSHOT=${token}`,
              `Mode: ${params.phase === "brainstorm" ? "BRAINSTORM" : "REVIEW"}`,
              `Phase: ${params.phase}; Round: ${round}; TargetFile: ${document}; LineRange: ${start}..${end}`,
              params.phase === "comprehension" ? `FeatureRange: 1..${active.plan?.split ? active.plan.split - 1 : lines}; DetailedRange: ${active.plan?.split ? `${active.plan.split}..${lines}` : "N/A"}. Return the complete paraphrase under both upstream headings, then findings. No standard or external references.` : "",
              `Approved snapshot files: ${JSON.stringify([...entries, ...standardEntries].map(entry => entry.path))}`,
              standard ? `Target Standard: ${standardEntries[0].path}. Read it in full.` : "No document standard.",
              `Read the target in full; audit the specified range. Tools read immutable text snapshots only, not the live filesystem. Use literal grep to search approved source files. Report missing evidence rather than inventing it. Return findings to the parent, never write a report or delegate.`,
              criteria ? `Explicit operator-approved review criteria: ${criteria}` : "",
            ].filter(Boolean).join("\n"),
          };
          let response;
          try {
            const resolved = await api.resolveSubagentLaunchContract({
              ...request, parentSessionId: sessionId, parentSessionFile: ctx.sessionManager.getSessionFile(),
              parentLeafId: ctx.sessionManager.getLeafId(), parentModel: ctx.model,
              sessionRoot: ctx.sessionManager.getSessionDir(),
              scopedModelIds: ctx.scopedModels.map(({ model }) => `${model.provider}/${model.id}`),
              availableModels: ctx.modelRegistry.getAvailable(),
              knownProviders: () => ctx.modelRegistry.getAll().map(model => model.provider),
              runtimeSnapshotHost: this.pi, projectTrusted: ctx.isProjectTrusted(),
            });
            if (!resolved.ok) throw new Error(resolved.message);
            await validateContract(resolved.contract, { agent, reader, profile: join(this.root, "reviewers", `${reviewer}.md`), runtimeExtensions: api.runtimeExtensions });
            active.launches++;
            response = await delegate(this.pi, api, request, controller.signal, update => onUpdate?.({ reviewer, ...update }));
            if (response.status === "completed" && response.launchContractDigest !== resolved.contract.launchContractDigest) throw new Error("Reviewer launch digest differs from approved preflight");
            const text = response.result?.kind === "text" ? response.result.text : "";
            const completed = response.status === "completed" && text.trim().length > 0;
            const report = await this.save(`${token}.md`, completed ? text : `# Reviewer not run\n\nStatus: ${response.status}\n${response.error ?? "No complete report"}\n\n${text}`);
            await this.save(`${token}.receipt.md`, "# EGM runtime evidence\n\n```json\n" + JSON.stringify({ compatibility: COMPATIBILITY, reviewer, phase: params.phase, round, attempt, requestId: request.requestId, ownerRunId: request.ownerRunId, nodeId, context: request.context, runId: response.runId, status: completed ? "completed" : "not run", runtimeStatus: response.status, model: response.model, thinking: response.thinking, launchContractDigest: response.launchContractDigest, usage: response.usage, providerDiagnostics: response.providerDiagnostics, report, reads: audit }, null, 2) + "\n```\n");
            if (completed || attempt === 2 || controller.signal.aborted || ["cancelled", "interrupted"].includes(response.status)) return { reviewer, status: completed ? "completed" : "not run", report, runId: response.runId, usage: response.usage };
          } catch (error) {
            active.poisoned = true;
            controller.abort();
            throw error;
          } finally { registry().delete(token); }
        }
      }).map((promise, index) => promise.catch(error => ({ reviewer: config.reviewers[index], status: "not run", error: error.message }))));
      const ok = results.every(result => result.status === "completed");
      if (active.sequence && ok && active.sequence[active.completed] === params.phase) active.completed++;
      return { status: ok ? "completed" : "partial", phase: params.phase, round, results, artifactDirectory: active.directory, next: active.sequence?.[active.completed] };
    } finally {
      ceiling?.dispose(); required?.dispose();
      this.controllers.delete(controller); signal?.removeEventListener("abort", abort);
      this.busy = false;
    }
  }
}
