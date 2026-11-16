import { randomUUID } from "node:crypto";
import { readFile, realpath } from "node:fs/promises";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const COMPATIBILITY = { pi: "1.5.2", subagents: "0.88.1", contract: 3 };
export const TOOLS = ["read", "grep", "find", "ls"];

// Resolve only documented package exports, anchored at Pi's actual mutable npm
// installation. Reuse the installed host's jiti and peer modules; install none.
export async function loadBackend({ agentDir, packageDir, version, SessionManager, hostModules }) {
  if (version !== COMPATIBILITY.pi) throw new Error(`EGM requires audited Pi ${COMPATIBILITY.pi}; found ${version}`);
  const runtimeRequire = createRequire(join(agentDir, "npm", "package.json"));
  const entry = runtimeRequire.resolve("pi-subagents");
  const manifest = JSON.parse(await readFile(join(dirname(dirname(entry)), "package.json"), "utf8"));
  if (manifest.name !== "pi-subagents" || manifest.version !== COMPATIBILITY.subagents) {
    throw new Error(`EGM requires audited pi-subagents ${COMPATIBILITY.subagents}; found ${manifest.version}`);
  }
  const hostRequire = createRequire(join(packageDir, "package.json"));
  const { createJiti } = hostRequire("jiti");
  const peers = ["@earendil-works/pi-coding-agent", "@earendil-works/pi-agent-core", "@earendil-works/pi-ai", "@earendil-works/pi-tui", "typebox"];
  const resolver = createJiti(join(packageDir, "package.json"));
  const alias = Object.fromEntries(peers.map(name => [name, resolver.esmResolve(name)]));
  // A bundled CLI's live SDK is not its adjacent unbundled dist/index.js.
  // jiti's public virtualModules option forwards Pi's actual mapped peer
  // exports, preserving class/registry identity in both bundled and SDK hosts.
  const loader = createJiti(join(packageDir, "package.json"), hostModules
    ? { virtualModules: hostModules, tryNative: false }
    : { alias, nativeModules: peers });
  if ((await loader.import(peers[0])).SessionManager !== SessionManager) throw new Error("EGM refused a second host SDK instance");
  const preflight = await loader.import(runtimeRequire.resolve("pi-subagents/preflight"));
  const ceilings = await loader.import(runtimeRequire.resolve("pi-subagents/capability-ceiling"));
  const required = await loader.import(runtimeRequire.resolve("pi-subagents/required-child-extensions"));
  const delegation = await loader.import(runtimeRequire.resolve("pi-subagents/delegation"));
  if (preflight.SUBAGENT_LAUNCH_CONTRACT_VERSION !== COMPATIBILITY.contract) throw new Error("Unsupported launch contract");
  // Version-specific audit of the one package-owned enforcement extension
  // reported by public preflight. This is a path comparison, not an import.
  const runtimeExtensions = [await realpath(join(dirname(dirname(entry)), "src/runs/shared/subagent-prompt-runtime.js"))];
  const inspectRuntimeSettings = async () => {
    try { return JSON.parse(await readFile(join(agentDir, "extensions/subagent/config.json"), "utf8")); }
    catch (error) { if (error.code === "ENOENT") return {}; throw error; }
  };
  return { ...preflight, ...ceilings, ...required, ...delegation, runtimeExtensions, inspectRuntimeSettings };
}

export function rpc(pi, method, params = {}, timeoutMs = 3000) {
  const requestId = randomUUID();
  return new Promise((resolve, reject) => {
    const event = `subagents:rpc:v1:reply:${requestId}`;
    const timer = setTimeout(() => { off(); reject(new Error("pi-subagents is missing or not ready; reload and retry explicitly")); }, timeoutMs);
    const off = pi.events.on(event, reply => {
      if (reply?.version !== 1 || reply.requestId !== requestId) return;
      clearTimeout(timer); off();
      if (reply.success) resolve(reply.data);
      else reject(new Error(reply.error?.message ?? "Subagent RPC failed"));
    });
    try { pi.events.emit("subagents:rpc:v1:request", { version: 1, requestId, method, params }); }
    catch (error) { clearTimeout(timer); off(); reject(error); }
  });
}

export async function validateContract(contract, { profile, reader, agent, runtimeExtensions = [] }) {
  const exact = (a, b) => JSON.stringify([...a].sort()) === JSON.stringify([...b].sort());
  if (contract.version !== COMPATIBILITY.contract || contract.protocol.packageVersion !== COMPATIBILITY.subagents
      || contract.agent.name !== agent || await realpath(contract.agent.filePath) !== await realpath(profile)
      || contract.context !== "fresh" || contract.systemPromptMode !== "replace"
      || contract.inheritProjectContext || contract.inheritGlobalContext || contract.inheritSkills
      || contract.skills.requested.length || contract.skills.resolved.length || contract.skills.missing.length
      || contract.intercomBridge.active || contract.intercomBridge.mode !== "off"
      || !contract.tools.explicitAllowlist || !exact(contract.tools.effectiveAllowlist, TOOLS)
      || contract.tools.fanoutAuthorized || contract.tools.effectiveMcpTools.length || contract.tools.mcp.length
      || contract.tools.internalTools.length || !contract.tools.disableAmbientExtensions
      || !exact(contract.tools.configuredExtensions, [reader])
      || !exact(contract.tools.requiredExtensionIds, ["phlake-egm-reader"])
      || !exact(contract.tools.runtimeExtensions, runtimeExtensions)
      || !exact(contract.tools.extensionArgs ?? [], runtimeExtensions)
      || contract.tools.toolExtensionPaths.length || contract.roots.outputPath
      || contract.diagnostics.some(item => item.severity === "error" || item.severity === "host-required")
      || typeof contract.launchContractDigest !== "string") {
    throw new Error("EGM reviewer launch contract was widened, shadowed, or cannot be established");
  }
}

export function delegate(pi, api, request, signal, onUpdate, cancellationGraceMs = 5000) {
  return new Promise((resolve, reject) => {
    let cancelling = false;
    let grace;
    let timer;
    const same = value => value?.requestId === request.requestId && value.ownerRunId === request.ownerRunId && value.nodeId === request.nodeId;
    const cleanup = () => {
      offResponse(); offUpdate(); clearTimeout(timer); clearTimeout(grace);
      signal?.removeEventListener("abort", cancel);
    };
    const cancel = () => {
      if (cancelling) return;
      cancelling = true;
      grace = setTimeout(() => { cleanup(); reject(new Error("Reviewer cancellation unacknowledged; stop EGM and inspect runtime before retrying")); }, cancellationGraceMs);
      try {
        pi.events.emit(api.SUBAGENT_DELEGATION_CANCEL_EVENT, {
          requestId: request.requestId, ownerRunId: request.ownerRunId, nodeId: request.nodeId,
        });
      } catch (error) { cleanup(); reject(error); }
    };
    const offUpdate = pi.events.on(api.SUBAGENT_DELEGATION_UPDATE_EVENT, update => { if (same(update)) onUpdate?.(update); });
    const offResponse = pi.events.on(api.SUBAGENT_DELEGATION_RESPONSE_EVENT, response => {
      if (!same(response)) return;
      cleanup();
      resolve(cancelling ? { ...response, status: "cancelled" } : response);
    });
    if (signal?.aborted) { cleanup(); reject(new Error("Review cancelled before dispatch")); return; }
    signal?.addEventListener("abort", cancel, { once: true });
    timer = setTimeout(cancel, request.timeoutMs + 1000);
    try { pi.events.emit(api.SUBAGENT_DELEGATION_REQUEST_EVENT, request); }
    catch (error) { cleanup(); reject(error); }
  });
}
