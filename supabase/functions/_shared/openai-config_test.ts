import {
  defaultReasoningEffort,
  reasoningEffort,
  responsesEndpoint,
  upstreamErrorKind,
} from "./openai-config.ts";

Deno.test("responsesEndpoint appends the Responses API path", () => {
  const endpoint = responsesEndpoint("https://api.3366.ai");
  if (endpoint.href !== "https://api.3366.ai/v1/responses") {
    throw new Error(`Unexpected endpoint: ${endpoint.href}`);
  }
});

Deno.test("responsesEndpoint accepts an existing v1 base path", () => {
  const endpoint = responsesEndpoint("https://example.com/v1/");
  if (endpoint.href !== "https://example.com/v1/responses") {
    throw new Error(`Unexpected endpoint: ${endpoint.href}`);
  }
});

Deno.test("responsesEndpoint rejects an insecure remote host", () => {
  let rejected = false;
  try {
    responsesEndpoint("http://example.com");
  } catch {
    rejected = true;
  }
  if (!rejected) throw new Error("Expected an insecure remote URL to fail");
});

Deno.test("reasoningEffort keeps medium and rejects unknown values", () => {
  if (reasoningEffort("medium") !== "medium") {
    throw new Error("Expected medium reasoning");
  }
  if (reasoningEffort("surprise") !== defaultReasoningEffort) {
    throw new Error("Expected the safe default reasoning effort");
  }
});

Deno.test("upstreamErrorKind separates auth, rate, and model failures", () => {
  if (
    upstreamErrorKind(401, "invalid_api_key", undefined, "bad key") !==
      "provider_authentication_failed"
  ) {
    throw new Error("Expected an authentication failure");
  }
  if (
    upstreamErrorKind(429, "rate_limit_exceeded", undefined, "slow down") !==
      "provider_rate_limited"
  ) {
    throw new Error("Expected a rate-limit failure");
  }
  if (
    upstreamErrorKind(404, "model_not_found", undefined, "unknown model") !==
      "model_not_supported"
  ) {
    throw new Error("Expected a model compatibility failure");
  }
});
