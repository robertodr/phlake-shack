import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { registry, snapshotOperations } from "./snapshots.mjs";

// Only loaded in native foreground reviewers, never as a parent extension.
export default function (pi: ExtensionAPI) {
  let operations: ReturnType<typeof snapshotOperations> | undefined;
  const names = ["read", "grep", "find", "ls"];
  const schemas = {
    read: Type.Object({
      path: Type.String(),
      offset: Type.Optional(Type.Integer({ minimum: 1 })),
      limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 2000 })),
    }, { additionalProperties: false }),
    grep: Type.Object({ pattern: Type.String(), path: Type.Optional(Type.String()) }, { additionalProperties: false }),
    find: Type.Object({ pattern: Type.Optional(Type.String()) }, { additionalProperties: false }),
    ls: Type.Object({}, { additionalProperties: false }),
  };
  for (const name of names) {
    pi.registerTool({
      name,
      label: `EGM snapshot ${name}`,
      description: `Read-only ${name} within the approved in-memory EGM snapshot only. No filesystem access. grep/find use literal substring matching, not regex/globs. Output limit: 48KB/2000 lines.`,
      parameters: schemas[name],
      async execute(_id, params) {
        if (!operations) throw new Error("No authorized EGM snapshot bound to this child");
        return { content: [{ type: "text", text: operations[name](params) }], details: {} };
      },
    });
  }
  pi.on("before_agent_start", (event) => {
    const matches = [...(event.prompt ?? "").matchAll(/EGM_SNAPSHOT=([a-f0-9-]{36})/g)];
    if (matches.length !== 1) throw new Error("Missing or ambiguous EGM snapshot identity");
    const snapshot = registry().get(matches[0][1]);
    if (!snapshot) throw new Error("Expired or foreign EGM snapshot");
    operations = snapshotOperations(snapshot.entries, snapshot.cwd, snapshot.audit);
    pi.setActiveTools(names);
  });
  pi.on("tool_call", (event) => {
    if (!operations || !names.includes(event.toolName)) return { block: true, reason: "EGM snapshot-only reviewer", terminate: true };
  });
  pi.on("session_shutdown", () => { operations = undefined; });
}
