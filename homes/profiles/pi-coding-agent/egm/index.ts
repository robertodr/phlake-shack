import { dirname, join } from "node:path";
import { realpath, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import {
  getAgentDir, getPackageDir, VERSION, SessionManager, withFileMutationQueue,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import * as hostSdk from "@earendil-works/pi-coding-agent";
import * as hostCore from "@earendil-works/pi-agent-core";
import * as hostAi from "@earendil-works/pi-ai";
import * as hostTui from "@earendil-works/pi-tui";
import * as hostTypebox from "typebox";
import * as hostCompile from "typebox/compile";
import * as hostValue from "typebox/value";
import { Type } from "typebox";
import { EgmEngine } from "./engine.mjs";
import { loadBackend, TOOLS } from "./backend.mjs";
import { skillInvocation } from "./protocol.mjs";

export default async function (pi: ExtensionAPI) {
  const root = await realpath(join(dirname(fileURLToPath(import.meta.url)), ".."));
  let backend: ReturnType<typeof loadBackend> | undefined;
  const engine = new EgmEngine({
    pi, root, mutate: withFileMutationQueue,
    backend: () => backend ??= loadBackend({
      agentDir: getAgentDir(), packageDir: getPackageDir(), version: VERSION, SessionManager,
      hostModules: { "@earendil-works/pi-coding-agent": hostSdk, "@earendil-works/pi-agent-core": hostCore,
        "@earendil-works/pi-ai": hostAi, "@earendil-works/pi-tui": hostTui, typebox: hostTypebox,
        "typebox/compile": hostCompile, "typebox/value": hostValue },
    })
      .catch(error => { backend = undefined; throw error; }),
  });
  let previousTools: string[] | undefined;
  const ownTools = ["egm_review_plan", "egm_reviewers", "egm_save", "egm_document"];
  const allowed = new Set(["read", "grep", "find", "ls", ...ownTools]);
  const result = (data: unknown) => ({ content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }], details: data });
  const exit = () => {
    engine.dispose();
    if (previousTools) pi.setActiveTools(previousTools);
    previousTools = undefined;
  };
  pi.on("input", async (event, ctx) => {
    const invocation = skillInvocation(event.text);
    if (!invocation) return;
    if (event.source === "extension" || event.streamingBehavior) {
      ctx.ui.notify("Start EGM explicitly while Pi is idle; installation or injected skill text does not authorize reviewers", "error");
      return { action: "handled" };
    }
    try {
      const active = await engine.start(invocation.skill, invocation.args, ctx.cwd);
      previousTools ??= pi.getActiveTools();
      pi.setActiveTools([...TOOLS, ...ownTools]);
      const skillPath = join(root, "skills", invocation.skill, "SKILL.md");
      const instructions = await readFile(skillPath, "utf8");
      const guide = await readFile(join(root, "adapter", "GUIDE.md"), "utf8");
      return { action: "transform", text: [
        `EGM invoked explicitly. Experimental local Pi integration; not officially supported or live-verified.`,
        `Bundle root: ${root}\nSkill directory: ${dirname(skillPath)}\nArtifact directory: ${active.directory}`,
        guide, instructions, `Operator request:\n${invocation.args}`,
      ].join("\n\n") };
    } catch (error) {
      // Input-handler errors normally leave Pi running. Handle this invocation
      // explicitly so failure cannot fall through to unconstrained skill text.
      const message = error instanceof Error ? error.message : String(error);
      if (ctx.hasUI) ctx.ui.notify(`EGM did not start: ${message}`, "error");
      else console.error(`EGM did not start: ${message}`);
      return { action: "handled" };
    }
  });
  pi.on("before_agent_start", event => {
    if (!engine.active) return;
    event.systemPromptOptions.sections["egm_workflow"] = `An explicitly invoked EGM document-only workflow is active. Follow its installed upstream skill and ${root}/adapter/GUIDE.md. No production code, builds, shell commands, MCP, or direct file mutations. Use egm_reviewers for fresh read-only reviewers, egm_save for artifacts and egm_document only for human-approved Markdown edits. Preserve one-question gates and yield human turns. Use /egm-exit to leave the workflow.`;
  });
  pi.on("tool_call", event => {
    if (engine.active && !allowed.has(event.toolName)) return { block: true, reason: "Active EGM workflow is document-only. Leave it explicitly before implementation.", terminate: true };
    if (ownTools.includes(event.toolName) && !engine.active) return { block: true, reason: "Invoke an EGM skill explicitly first" };
  });
  pi.on("session_shutdown", () => { engine.dispose(); previousTools = undefined; });
  // Tree navigation never replays paid work or restores an unreviewed permission.
  pi.on("session_tree", exit);
  pi.registerCommand("egm-exit", { description: "Leave EGM design-only scope and restore the previous tool selection", handler: async (_args, ctx) => {
    if (engine.busy) { engine.dispose(); throw new Error("Review cancellation requested; wait for settlement before leaving EGM"); }
    exit();
    pi.sendMessage({ customType: "egm-exit", content: "EGM workflow ended. Its design-only rules are no longer active; ordinary coding authorization rules apply.", display: true });
    ctx.ui.notify("Left EGM; previous tools restored", "info");
  } });
  pi.registerCommand("egm-doctor", { description: "Check EGM public APIs and backend readiness without starting any child or model request", handler: async (_args, ctx) => {
    await engine.backend();
    const { rpc } = await import("./backend.mjs");
    await rpc(pi, "ping");
    const message = "EGM offline doctor: audited host SDK identity, public API imports and backend readiness passed. No reviewers launched; live isolation and full workflows remain unverified.";
    if (ctx.hasUI) ctx.ui.notify(message, "info"); else console.error(message);
  } });
  pi.registerCommand("egm-status", { description: "Show local EGM workflow status without launching reviewers", handler: async (_args, ctx) => {
    const active = engine.active;
    const status = active ? `${active.skill}; ${active.launches}/120 attempts; artifacts: ${active.directory}${active.poisoned ? "; STOPPED: inspect runtime" : ""}` : "No active EGM workflow";
    if (ctx.hasUI) ctx.ui.notify(status, "info"); else console.error(status);
  } });
  pi.registerCommand("egm-smoke", { description: "Prepare a one-persona EGM prototype (not a full review); live dispatch still needs confirmation", handler: async (args, ctx) => {
    if (!args.trim()) throw new Error("Usage: /egm-smoke path/to/disposable.md");
    const active = await engine.start("smoke", args, ctx.cwd);
    previousTools ??= pi.getActiveTools();
    pi.setActiveTools([...TOOLS, ...ownTools]);
    pi.sendUserMessage(`Run only the isolated EGM prototype: call egm_reviewers with phase=smoke and document=${JSON.stringify(args.trim())}. This is not egm-review and proves no live isolation until actual child inputs and denied mutation attempts are inspected. Save results under ${active.directory}.`);
  } });
  pi.registerTool({
    name: "egm_review_plan", label: "EGM review plan", defaultActive: false, exposure: "model-only", executionMode: "sequential",
    description: "Configure egm-review's upstream preset, semantic split and approved references. No model calls. Preserve intake questions and let the human select the preset.",
    parameters: Type.Object({ document: Type.String(), splitLine: Type.Optional(Type.Integer({ minimum: 2 })), references: Type.Optional(Type.Array(Type.String(), { maxItems: 16 })), initialReport: Type.Optional(Type.String()) }, { additionalProperties: false }),
    async execute(_id, params, _signal, _update, ctx) { return result(await engine.plan(params, ctx)); },
  });
  pi.registerTool({
    name: "egm_reviewers", label: "EGM fresh reviewers", defaultActive: false, exposure: "model-only", executionMode: "sequential",
    description: "Dispatch one bounded upstream EGM stage using fresh snapshot-only foreground reviewers. Requires explicit workflow invocation, human launch approval, and an audited pi-subagents backend. Returns report/evidence paths and completed/not run status, never implicit approval. No resume/fork or same-session fallback.",
    parameters: Type.Object({
      phase: Type.String({ enum: ["smoke", "brainstorm", "initial", "comprehension", "critic", "intermediate", "readiness", "loop", "bootstrap"] }),
      document: Type.Optional(Type.String()), references: Type.Optional(Type.Array(Type.String(), { maxItems: 16 })),
      startLine: Type.Optional(Type.Integer({ minimum: 1 })), endLine: Type.Optional(Type.Integer({ minimum: 1 })),
      reviewers: Type.Optional(Type.Array(Type.String(), { maxItems: 8 })), standards: Type.Optional(Type.Record(Type.String(), Type.String())),
      criteria: Type.Optional(Type.String({ maxLength: 4000 })),
    }, { additionalProperties: false }),
    async execute(_id, params, signal, update, ctx) {
      const data = await engine.review(params, ctx, signal, event => update?.(result({ reviewer: event.reviewer, runId: event.runId, currentTool: event.currentTool, durationMs: event.durationMs })));
      return { ...result(data), isError: data.status === "partial", terminate: data.status === "paused" };
    },
  });
  pi.registerTool({
    name: "egm_save", label: "EGM artifact", defaultActive: false, exposure: "model-only", executionMode: "sequential",
    description: "Save a Markdown draft, synthesized report or brief in the approved EGM artifact directory. Simple filename only, at most 1 MiB. Artifact delivery is not approval to implement.",
    parameters: Type.Object({ name: Type.String(), content: Type.String() }, { additionalProperties: false }),
    async execute(_id, params) { return result({ path: await engine.save(params.name, params.content) }); },
  });
  pi.registerTool({
    name: "egm_document", label: "EGM approved document", defaultActive: false, exposure: "model-only", executionMode: "sequential",
    description: "Propose a project Markdown update, then obtain human approval of its exact path and proposed artifact before saving. Never changes production code or instruction files. Use only at upstream-approved document transitions; otherwise save an artifact first.",
    parameters: Type.Object({ path: Type.String(), content: Type.String() }, { additionalProperties: false }),
    async execute(_id, params, _signal, _update, ctx) { return result(await engine.saveDocument(params.path, params.content, ctx)); },
  });
}
