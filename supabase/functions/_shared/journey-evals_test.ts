import {
  validateJourneyRequest,
  validateJourneyResponse,
} from "./journey-validation.ts";

interface EvalCase {
  id: string;
  request: unknown;
  response: unknown;
  expectedValid: boolean;
}
const fixtures = [
  "dayvault-achievement-designer/evals/zh-Hans-cases.jsonl",
  "dayvault-companion/evals/zh-Hans-cases.jsonl",
  "dayvault-goal-planner/evals/adjustment-zh-Hans-cases.jsonl",
];
for (const fixture of fixtures) {
  const text = await Deno.readTextFile(
    new URL(`../../../AI/Skills/${fixture}`, import.meta.url),
  );
  for (const line of text.trim().split("\n")) {
    const evaluation = JSON.parse(line) as EvalCase;
    Deno.test(`Chinese contract eval: ${evaluation.id}`, () => {
      let accepted = true;
      try {
        const request = validateJourneyRequest(evaluation.request);
        validateJourneyResponse(evaluation.response, request);
      } catch {
        accepted = false;
      }
      if (accepted !== evaluation.expectedValid) {
        throw new Error(`Unexpected validation outcome: ${evaluation.id}`);
      }
    });
  }
}
