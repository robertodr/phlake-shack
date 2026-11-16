export const SKILLS = ["egm-brainstorm", "egm-draft", "egm-review", "egm-review-loop", "egm-resolve", "egm-bootstrap", "egm-drift-report"];
export const PERSONAS = {
  "egm-design": "design_critic",
  "egm-codebase-details": "codebase_details",
  "egm-comprehension": "comprehension",
  "egm-implementation-readiness": "implementation_readiness",
  "egm-structural": "structural",
  "egm-style": "style",
  "egm-zoom-out": "zoom_out",
  "egm-inventive-catalyst": "inventive_catalyst",
};
export const STANDARDS = ["feature-spec-standard", "heilmeier-standard", "implementation-readiness-standard", "re-implementation-standard", "zoom-out-standard"];
export const PHASES = {
  smoke: { reviewers: ["egm-comprehension"], documentOnly: true },
  brainstorm: { reviewers: ["egm-design", "egm-codebase-details", "egm-zoom-out", "egm-comprehension", "egm-implementation-readiness", "egm-structural", "egm-inventive-catalyst"] },
  initial: { reviewers: ["egm-zoom-out", "egm-inventive-catalyst"], standards: { "egm-zoom-out": "zoom-out-standard" } },
  comprehension: { reviewers: ["egm-comprehension"], documentOnly: true },
  critic: { reviewers: ["egm-design", "egm-structural", "egm-style"], standards: { "egm-design": "feature-spec-standard", "egm-structural": "feature-spec-standard" } },
  intermediate: { reviewers: ["egm-zoom-out"], standards: { "egm-zoom-out": "zoom-out-standard" } },
  readiness: { reviewers: ["egm-implementation-readiness", "egm-codebase-details", "egm-style"], standards: { "egm-implementation-readiness": "implementation-readiness-standard", "egm-codebase-details": "implementation-readiness-standard" } },
  loop: {},
  bootstrap: { reviewers: ["goldfish-explorer"] },
};
export function phaseConfig(phase, reviewers, standards) {
  const config = PHASES[phase];
  if (!config) throw new Error("Unknown EGM phase");
  if (phase !== "loop" && (reviewers !== undefined || standards !== undefined)) throw new Error("Fixed upstream stage cannot change personas or standards");
  const result = phase === "loop" ? { reviewers, standards: standards ?? {} } : config;
  if (!Array.isArray(result.reviewers) || !result.reviewers.length || result.reviewers.length > 8
      || new Set(result.reviewers).size !== result.reviewers.length
      || result.reviewers.some(name => !Object.hasOwn(PERSONAS, name) && !(phase === "bootstrap" && name === "goldfish-explorer"))) {
    throw new Error("Select 1–8 distinct upstream leaf reviewers (no orchestrator agents)");
  }
  if (Object.entries(result.standards ?? {}).some(([name, standard]) => !result.reviewers.includes(name) || !STANDARDS.includes(standard))) {
    throw new Error("Unsupported persona/standard mapping");
  }
  return result;
}

export function reviewSequence(preset) {
  if (preset === "feature_spec") return ["initial", "comprehension", "critic", "intermediate"];
  if (preset === "implementation") return ["readiness"];
  if (["interactive", "uninterrupted"].includes(preset)) return ["initial", "comprehension", "critic", "intermediate", "readiness"];
  const singles = { "5": "initial", "6": "comprehension", "7": "critic", "8": "intermediate", "9": "readiness" };
  if (singles[preset]) return [singles[preset]];
  throw new Error("Unknown EGM review preset");
}

export function skillInvocation(text) {
  const match = /^\/skill:(egm-[a-z-]+)(?:\s+([\s\S]*))?$/.exec(text.trim());
  return match && SKILLS.includes(match[1]) ? { skill: match[1], args: match[2] ?? "" } : undefined;
}
