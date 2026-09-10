import {
  providerSchema,
  readOpenAIResponse,
  structuredOutputText,
  validateSchema,
} from "./structured-output.ts";
import { plannerOutputSchema } from "./dayvault-goal-planner.bundle.ts";

function assert(
  condition: unknown,
  message = "Assertion failed",
): asserts condition {
  if (!condition) throw new Error(message);
}
async function rejects(action: () => unknown | Promise<unknown>) {
  let rejected = false;
  try {
    await action();
  } catch {
    rejected = true;
  }
  assert(rejected, "Expected malformed or incomplete output to be rejected");
}
function stream(chunks: string[]): Response {
  return new Response(
    new ReadableStream({
      start(controller) {
        chunks.forEach((chunk) =>
          controller.enqueue(new TextEncoder().encode(chunk))
        );
        controller.close();
      },
    }),
    { headers: { "Content-Type": "text/event-stream" } },
  );
}

Deno.test("provider schema removes only unsupported uniqueness; source contract is unchanged", () => {
  const original = JSON.stringify(plannerOutputSchema);
  const wire = JSON.stringify(providerSchema(plannerOutputSchema));
  assert(original.includes('"uniqueItems":true'));
  assert(!wire.includes("uniqueItems"));
  assert(
    wire.includes('"format":"uuid"') &&
      wire.includes('"additionalProperties":false'),
  );
  assert(original === JSON.stringify(plannerOutputSchema));
});

Deno.test("full local schema still rejects duplicate weekdays", async () => {
  const schema = {
    type: "array",
    uniqueItems: true,
    items: { type: "integer", minimum: 1, maximum: 7 },
  };
  validateSchema([2, 4, 6], schema);
  await rejects(() => validateSchema([2, 2], schema));
  await rejects(() => validateSchema([8], schema));
});

Deno.test("schema rejects model-authored metadata, invalid IDs and missing fields", async () => {
  const valid = {
    kind: "clarification",
    question: "你想推进哪件事？",
    plan: null,
  };
  validateSchema(valid, plannerOutputSchema);
  await rejects(() =>
    validateSchema({ ...valid, model: "example-model" }, plannerOutputSchema)
  );
  await rejects(() =>
    validateSchema({ kind: "clarification" }, plannerOutputSchema)
  );
  await rejects(() =>
    validateSchema("not-an-id", { type: "string", format: "uuid" })
  );
  await rejects(() =>
    validateSchema("tomorrow", { type: "string", format: "date-time" })
  );
});

Deno.test("Responses stream accepts only completed result across split CRLF frames", async () => {
  const terminal = {
    type: "response.completed",
    response: { status: "completed", output_text: '{"kind":"clarification"}' },
  };
  const result = await readOpenAIResponse(stream([
    ": keepalive\r\n\r\n",
    'event: response.output_text.delta\r\ndata: {"type":"response.output_text.delta","delta":"partial"}\r',
    "\n\r\ndata: " + JSON.stringify(terminal) + "\r\n\r",
    "\n",
  ]));
  assert(result.status === "completed");
  assert(result.output_text === '{"kind":"clarification"}');
});

Deno.test("truncated Responses stream never becomes a usable draft", async () => {
  await rejects(() =>
    readOpenAIResponse(stream([
      'data: {"type":"response.output_text.delta","delta":"{}"}\n\n',
      "data: [DONE]\n\n",
    ]))
  );
  await rejects(() =>
    readOpenAIResponse(stream([
      'data: {"type":"response.incomplete","response":{"status":"incomplete"}}\n\n',
    ]))
  );
});

Deno.test("Responses stream rejects error events and oversized data", async () => {
  await rejects(() =>
    readOpenAIResponse(stream(['data: {"type":"error"}\n\n']))
  );
  await rejects(() => readOpenAIResponse(stream(["x".repeat(2_000_001)])));
});

Deno.test("non-streaming JSON compatibility and HTTP error envelopes remain readable", async () => {
  const result = await readOpenAIResponse(
    new Response(JSON.stringify({ status: "completed", output_text: "{}" })),
  );
  assert(result.output_text === "{}");
  const error = await readOpenAIResponse(
    new Response('{"error":"upstream failure"}', { status: 400 }),
  );
  assert(error.error === "upstream failure");
});

Deno.test("malformed provider envelopes fail safely instead of crashing the handler", async () => {
  await rejects(() => readOpenAIResponse(new Response("null")));
  await rejects(() =>
    readOpenAIResponse(
      stream(['data: {"type":"response.completed","response":null}\n\n']),
    )
  );
  assert(structuredOutputText({ output: [{ content: [] }] }) === undefined);
  assert(
    structuredOutputText({
      output: [{ content: [{ type: "output_text", text: "{}" }] }],
    }) === "{}",
  );
});
