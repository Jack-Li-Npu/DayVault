import {
  plannerInstructions,
  plannerOutputSchema,
  skillVersion,
} from "./dayvault-goal-planner.bundle.ts";
import { journeyBundles } from "./dayvault-journey.bundle.ts";

const skillRoot = new URL(
  "../../../AI/Skills/dayvault-goal-planner/",
  import.meta.url,
);
const initialReferences = [
  "references/scheduling-policy.md",
  "references/domain-playbooks.md",
  "references/planner-contract.md",
];

async function source(path: string): Promise<string> {
  return await Deno.readTextFile(new URL(path, skillRoot));
}

async function voiceSource(): Promise<string> {
  return await Deno.readTextFile(
    new URL("../../Editorial/voice.md", skillRoot),
  );
}

Deno.test("initial planner bundles every runtime reference without stale content", async () => {
  const documents = await Promise.all(
    ["SKILL.md", ...initialReferences].map(source),
  );
  if (
    plannerInstructions !== [...documents, await voiceSource()].join("\n\n")
  ) {
    throw new Error("Regenerate the planner bundle from all runtime sources");
  }
  const version = documents[0].match(/version:\s*([^\s]+)/)?.[1];
  if (skillVersion !== version || skillVersion !== "1.1.1") {
    throw new Error("Planner bundle version does not match its source");
  }
});

Deno.test("initial planner schema stays identical to the app contract source", async () => {
  const document = JSON.parse(await source("references/output-schema.json"));
  if (JSON.stringify(plannerOutputSchema) !== JSON.stringify(document.schema)) {
    throw new Error("Planner schema and bundle differ");
  }
});

Deno.test("readable Chinese prompt is exactly the runtime instructions", async () => {
  if (await source("PROMPT.zh-CN.md") !== plannerInstructions) {
    throw new Error(
      "Readable prompt is stale or differs from the runtime bundle",
    );
  }
});

Deno.test("all AI operations load the same voice rules without changing response schemas", async () => {
  const voice = await voiceSource();
  if (!plannerInstructions.endsWith(voice)) {
    throw new Error("Planner voice rules missing");
  }
  for (const bundle of Object.values(journeyBundles)) {
    if (!bundle.instructions.endsWith(voice)) {
      throw new Error("Journey voice rules missing");
    }
    if (bundle.schema.properties.skillVersion.enum[0] !== "1.0.0") {
      throw new Error(
        "Editorial changes must not change the response contract",
      );
    }
  }
  for (
    const boundary of [
      "不冒充真人",
      "不得为了使文字自然而添加数据",
      "保留“AI 生成”“本地演示”等来源标识",
      "不能以“更自然”为由删掉",
    ]
  ) {
    if (!voice.includes(boundary)) {
      throw new Error("Editorial safety boundary missing");
    }
  }
});

Deno.test("adjustment keeps its own policy and frozen response version", async () => {
  const [entry, policy, schemaText, ...initialOnly] = await Promise.all([
    source("SKILL.md"),
    source("references/adjustment-policy.md"),
    source("references/adjustment-schema.json"),
    ...initialReferences.map(source),
  ]);
  const bundle = journeyBundles.suggestAdjustment;
  if (
    bundle.instructions !== `${entry}\n\n${policy}\n\n${await voiceSource()}`
  ) {
    throw new Error(
      "Adjustment must load only the shared entry and its own policy",
    );
  }
  if (initialOnly.some((document) => bundle.instructions.includes(document))) {
    throw new Error(
      "Initial-plan defaults leaked into the adjustment operation",
    );
  }
  if (
    JSON.stringify(bundle.schema) !==
      JSON.stringify(JSON.parse(schemaText).schema)
  ) {
    throw new Error("Adjustment schema changed during a prompt-only revision");
  }
  if (bundle.schema.properties.skillVersion.enum[0] !== "1.0.0") {
    throw new Error("Keep the existing Swift/TypeScript response contract");
  }
});

Deno.test("achievement designer loads its exact source rules and frozen schema", async () => {
  const root = new URL("../dayvault-achievement-designer/", skillRoot);
  const [entry, rules, schema] = await Promise.all([
    Deno.readTextFile(new URL("SKILL.md", root)),
    Deno.readTextFile(new URL("references/rules.md", root)),
    Deno.readTextFile(new URL("references/output-schema.json", root)),
  ]);
  const bundle = journeyBundles.designAchievements;
  if (bundle.instructions !== `${entry}\n\n${rules}\n\n${await voiceSource()}`) {
    throw new Error("Achievement designer is missing current source guidance");
  }
  if (bundle.version !== entry.match(/version:\s*([^\s]+)/)?.[1]) {
    throw new Error("Achievement designer version differs from source");
  }
  if (JSON.stringify(bundle.schema) !== JSON.stringify(JSON.parse(schema).schema)) {
    throw new Error("Achievement design schema differs from its source contract");
  }
});

interface PlannerEvalCase {
  id: string;
  request: {
    goalText: string;
    currentDate: string;
    timeZoneID: string;
    busyWindows: Array<{ start: string; end: string }>;
  };
  expectedKind: string;
  rubric: string[];
}

Deno.test("planner behavioral cases are valid fixtures, not claimed model results", async () => {
  const cases: PlannerEvalCase[] =
    (await source("evals/planner-v1.1-cases.jsonl"))
      .trim().split("\n").map((line) => JSON.parse(line));
  if (
    cases.length !== 18 ||
    new Set(cases.map((item) => item.id)).size !== cases.length
  ) {
    throw new Error("Expected 18 distinct review cases");
  }
  for (const item of cases) {
    if (
      !item.request.goalText ||
      !Number.isFinite(Date.parse(item.request.currentDate))
    ) {
      throw new Error(`Invalid synthetic request: ${item.id}`);
    }
    new Intl.DateTimeFormat("en", { timeZone: item.request.timeZoneID });
    for (const window of item.request.busyWindows) {
      if (!(Date.parse(window.start) < Date.parse(window.end))) {
        throw new Error(`Invalid busy window: ${item.id}`);
      }
    }
    if (
      !["plan", "clarification"].includes(item.expectedKind) ||
      item.rubric.length < 2
    ) {
      throw new Error(`Missing observable review criteria: ${item.id}`);
    }
  }
});
