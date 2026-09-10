// Keep the full application schema for validation. Only the wire copy omits
// keywords outside OpenAI's Structured Outputs subset.
export function providerSchema(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(providerSchema);
  if (!isObject(value)) return value;
  return Object.fromEntries(
    Object.entries(value).filter(([key]) => key !== "uniqueItems")
      .map(([key, child]) => [key, providerSchema(child)]),
  );
}

function isObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

// The bundled contracts use this deliberately limited subset. A removed wire
// constraint must still be checked here; no model output can bypass validation.
export function validateSchema(value: unknown, schema: unknown): void {
  if (!isObject(schema)) throw new Error("invalid_schema");
  if (Array.isArray(schema.anyOf)) {
    for (const branch of schema.anyOf) {
      try {
        validateSchema(value, branch);
        return;
      } catch { /* Try the next branch. */ }
    }
    throw new Error("schema_union");
  }
  const types = Array.isArray(schema.type) ? schema.type : [schema.type];
  let type: string = typeof value;
  if (value === null) type = "null";
  else if (Array.isArray(value)) type = "array";
  if (
    !types.includes(type) &&
    !(types.includes("integer") && Number.isInteger(value))
  ) {
    throw new Error("schema_type");
  }
  if (Array.isArray(schema.enum) && !schema.enum.includes(value)) {
    throw new Error("schema_enum");
  }
  if (isObject(value)) {
    const properties = isObject(schema.properties) ? schema.properties : {};
    if (
      Array.isArray(schema.required) &&
      schema.required.some((key) =>
        typeof key !== "string" || !Object.hasOwn(value, key)
      )
    ) {
      throw new Error("schema_required");
    }
    for (const [key, child] of Object.entries(value)) {
      if (!Object.hasOwn(properties, key)) {
        if (schema.additionalProperties === false) {
          throw new Error("schema_extra_field");
        }
      } else validateSchema(child, properties[key]);
    }
  } else if (Array.isArray(value)) {
    if (
      typeof schema.minItems === "number" && value.length < schema.minItems ||
      typeof schema.maxItems === "number" && value.length > schema.maxItems
    ) throw new Error("schema_array_size");
    if (
      schema.uniqueItems === true &&
      new Set(value.map((item) => JSON.stringify(item))).size !== value.length
    ) throw new Error("schema_duplicates");
    if (schema.items) {
      value.forEach((item) => validateSchema(item, schema.items));
    }
  } else if (typeof value === "string") {
    if (
      typeof schema.minLength === "number" && value.length < schema.minLength ||
      typeof schema.maxLength === "number" && value.length > schema.maxLength
    ) throw new Error("schema_string_size");
    if (
      schema.format === "uuid" &&
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        value,
      )
    ) throw new Error("schema_uuid");
    if (
      schema.format === "date-time" &&
      (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/.test(
        value,
      ) || !Number.isFinite(Date.parse(value)))
    ) throw new Error("schema_date");
  } else if (typeof value === "number") {
    if (
      !Number.isFinite(value) ||
      typeof schema.minimum === "number" && value < schema.minimum ||
      typeof schema.maximum === "number" && value > schema.maximum
    ) throw new Error("schema_number");
  }
}

export interface OpenAIResponseBody {
  status?: string;
  error?: string | { code?: unknown; message?: unknown; type?: unknown };
  output?: Array<{ content?: Array<{ type?: string; text?: string }> }>;
  output_text?: unknown;
}

export function structuredOutputText(
  body: OpenAIResponseBody,
): string | undefined {
  if (typeof body.output_text === "string") return body.output_text;
  if (!Array.isArray(body.output)) return undefined;
  for (const item of body.output) {
    if (!isObject(item) || !Array.isArray(item.content)) continue;
    for (const content of item.content) {
      if (
        isObject(content) && content.type === "output_text" &&
        typeof content.text === "string"
      ) return content.text;
    }
  }
}

// Streaming reduces relay idle-timeout failures, but gateways may still time out.
// Only a terminal completed response is accepted, never partial JSON/deltas.
export async function readOpenAIResponse(
  response: Response,
): Promise<OpenAIResponseBody> {
  if (
    !response.ok ||
    !response.headers.get("content-type")?.includes("text/event-stream")
  ) {
    const body: unknown = await response.json();
    if (!isObject(body)) throw new Error("invalid_response_body");
    return body;
  }
  if (!response.body) throw new Error("missing_response_body");
  const reader = response.body.pipeThrough(new TextDecoderStream()).getReader();
  let buffer = "";
  let bytes = 0;
  let completed: OpenAIResponseBody | undefined;
  function consume(frame: string): void {
    const data = frame.split("\n").filter((line) => line.startsWith("data:"))
      .map((line) => line.slice(5).trimStart()).join("\n");
    if (!data || data === "[DONE]") return;
    const event = JSON.parse(data);
    if (event.type === "response.completed") {
      if (!isObject(event.response) || event.response.status !== "completed") {
        throw new Error("invalid_completed_response");
      }
      completed = event.response;
    }
    if (
      ["response.failed", "response.incomplete", "error"].includes(event.type)
    ) throw new Error("incomplete_output");
  }
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      bytes += value.length;
      if (bytes > 2_000_000) throw new Error("response_too_large");
      buffer += value;
      // Accept LF and CRLF boundaries, including those split across chunks.
      let boundary: RegExpExecArray | null;
      while ((boundary = /\r?\n\r?\n/.exec(buffer)) !== null) {
        consume(buffer.slice(0, boundary.index).replaceAll("\r\n", "\n"));
        buffer = buffer.slice(boundary.index + boundary[0].length);
      }
      if (completed) return completed;
    }
    if (buffer.trim()) consume(buffer.replaceAll("\r\n", "\n"));
    if (!completed) throw new Error("incomplete_output");
    return completed;
  } finally {
    await reader.cancel();
    reader.releaseLock();
  }
}
