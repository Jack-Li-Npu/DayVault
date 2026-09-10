import {
  plannerInstructions,
  plannerOutputSchema,
  skillVersion,
} from "../_shared/dayvault-goal-planner.bundle.ts";
import {
  defaultOpenAIBaseURL,
  defaultOpenAIModel,
  reasoningEffort,
  responsesEndpoint,
  upstreamErrorKind,
} from "../_shared/openai-config.ts";
import { journeyBundles } from "../_shared/dayvault-journey.bundle.ts";
import {
  type JourneyRequest,
  validateJourneyRequest,
  validateJourneyResponse,
} from "../_shared/journey-validation.ts";

const jsonHeaders = { "Content-Type": "application/json; charset=utf-8" };

type OpenAIResponseBody = {
  error?: string | { code?: unknown; message?: unknown; type?: unknown };
  output?: Array<{
    content?: Array<{ type?: string; text?: string }>;
  }>;
  output_text?: unknown;
};

Deno.serve({
  hostname: Deno.env.get("DAYVAULT_SERVER_HOST") ?? "0.0.0.0",
}, async (request) => {
  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), {
      status: 405,
      headers: jsonHeaders,
    });
  }

  const openAIKey = Deno.env.get("OPENAI_API_KEY");
  if (!openAIKey) {
    return new Response(JSON.stringify({ error: "missing_openai_key" }), {
      status: 503,
      headers: jsonHeaders,
    });
  }

  const allowPreview =
    Deno.env.get("DAYVAULT_ALLOW_UNAUTHENTICATED_PREVIEW") === "true";
  let userIdentity = "unauthenticated-preview";
  if (!allowPreview) {
    const authenticatedUserID = await getAuthenticatedUserID(request);
    if (!authenticatedUserID) {
      return new Response(
        JSON.stringify({ error: "authentication_required" }),
        { status: 401, headers: jsonHeaders },
      );
    }
    userIdentity = authenticatedUserID;
  }

  let plannerRequest: Record<string, unknown>;
  try {
    const body = await request.text();
    if (body.length > 64_000) throw new Error("request_too_large");
    const parsed: unknown = JSON.parse(body);
    if (
      typeof parsed !== "object" || parsed === null || Array.isArray(parsed)
    ) throw new Error("invalid_request");
    plannerRequest = parsed as Record<string, unknown>;
  } catch {
    return new Response(JSON.stringify({ error: "invalid_json" }), {
      status: 400,
      headers: jsonHeaders,
    });
  }

  let journeyRequest: JourneyRequest | undefined;
  if (Object.hasOwn(plannerRequest, "operation")) {
    try {
      journeyRequest = validateJourneyRequest(plannerRequest);
    } catch {
      return new Response(
        JSON.stringify({ error: "invalid_journey_request" }),
        { status: 422, headers: jsonHeaders },
      );
    }
  }
  const goal = typeof plannerRequest.goalText === "string"
    ? plannerRequest.goalText.trim()
    : "";
  if (!journeyRequest && (goal.length < 1 || goal.length > 500)) {
    return new Response(JSON.stringify({ error: "invalid_goal" }), {
      status: 422,
      headers: jsonHeaders,
    });
  }

  const safetyIdentifier = await sha256(userIdentity);
  let openAIEndpoint: URL;
  try {
    openAIEndpoint = responsesEndpoint(
      Deno.env.get("OPENAI_BASE_URL") ?? defaultOpenAIBaseURL,
    );
  } catch {
    return new Response(JSON.stringify({ error: "invalid_openai_base_url" }), {
      status: 503,
      headers: jsonHeaders,
    });
  }

  const bundle = journeyRequest
    ? journeyBundles[journeyRequest.operation]
    : undefined;
  let openAIResponse: Response;
  try {
    openAIResponse = await fetch(openAIEndpoint, {
      method: "POST",
      signal: AbortSignal.timeout(60_000),
      headers: {
        "Authorization": `Bearer ${openAIKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("DAYVAULT_OPENAI_MODEL") ?? defaultOpenAIModel,
        reasoning: {
          effort: reasoningEffort(
            Deno.env.get("DAYVAULT_OPENAI_REASONING_EFFORT"),
          ),
        },
        store: false,
        max_output_tokens: journeyRequest ? 4000 : 8000,
        safety_identifier: safetyIdentifier,
        prompt_cache_key: bundle
          ? `dayvault-${journeyRequest!.operation}:${bundle.version}`
          : `dayvault-goal-planner:${skillVersion}`,
        instructions: bundle?.instructions ?? plannerInstructions,
        input: [{
          role: "user",
          content: [{
            type: "input_text",
            text: JSON.stringify(
              journeyRequest ?? { ...plannerRequest, skillVersion },
            ),
          }],
        }],
        text: {
          format: {
            type: "json_schema",
            name: journeyRequest
              ? `dayvault_${journeyRequest.operation}`
              : "dayvault_planner_turn",
            strict: true,
            schema: bundle?.schema ?? plannerOutputSchema,
          },
        },
      }),
    });
  } catch {
    return new Response(JSON.stringify({ error: "provider_unavailable" }), {
      status: 503,
      headers: jsonHeaders,
    });
  }

  const responseText = await openAIResponse.text();
  let responseBody: OpenAIResponseBody = {};
  try {
    responseBody = JSON.parse(responseText);
  } catch {
    if (openAIResponse.ok) {
      return new Response(
        JSON.stringify({ error: "invalid_openai_response" }),
        { status: 502, headers: jsonHeaders },
      );
    }
  }
  if (!openAIResponse.ok) {
    const upstreamError = typeof responseBody.error === "object"
      ? responseBody.error
      : undefined;
    const upstreamMessage = typeof upstreamError?.message === "string"
      ? upstreamError.message
      : typeof responseBody.error === "string"
      ? responseBody.error
      : "";
    const error = upstreamErrorKind(
      openAIResponse.status,
      upstreamError?.code,
      upstreamError?.type,
      upstreamMessage,
    );
    return new Response(
      JSON.stringify({
        error,
      }),
      {
        status: 502,
        headers: jsonHeaders,
      },
    );
  }

  const outputText = typeof responseBody.output_text === "string"
    ? responseBody.output_text
    : responseBody.output
      ?.flatMap((item) => item.content ?? [])
      .find((content) => content.type === "output_text")?.text;
  if (typeof outputText !== "string") {
    return new Response(
      JSON.stringify({ error: "missing_structured_output" }),
      { status: 502, headers: jsonHeaders },
    );
  }

  try {
    const result = JSON.parse(outputText);
    if (journeyRequest) validateJourneyResponse(result, journeyRequest);
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: jsonHeaders,
    });
  } catch {
    return new Response(
      JSON.stringify({ error: "invalid_structured_output" }),
      { status: 502, headers: jsonHeaders },
    );
  }
});

async function getAuthenticatedUserID(
  request: Request,
): Promise<string | null> {
  const authorization = request.headers.get("Authorization");
  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!authorization?.startsWith("Bearer ") || !supabaseURL || !supabaseKey) {
    return null;
  }

  const response = await fetch(`${supabaseURL}/auth/v1/user`, {
    headers: {
      Authorization: authorization,
      apikey: supabaseKey,
    },
  });
  if (!response.ok) {
    return null;
  }
  const user = await response.json();
  return typeof user?.id === "string" ? user.id : null;
}

async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}
