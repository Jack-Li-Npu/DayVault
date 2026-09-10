import {
  defaultOpenAIBaseURL,
  defaultOpenAIModel,
  defaultReasoningEffort,
  isUpstreamTimeout,
  reasoningEffort,
  responsesEndpoint,
  upstreamErrorKind,
} from "./openai-config.ts";

Deno.test("published defaults contain only nonfunctional provider placeholders", () => {
  if (defaultOpenAIBaseURL !== "https://api.example.com") {
    throw new Error("Expected a placeholder endpoint");
  }
  if (defaultOpenAIModel !== "example-model") {
    throw new Error("Expected a placeholder model");
  }
  if (defaultReasoningEffort !== "medium") {
    throw new Error("Expected medium reasoning by default");
  }
});

Deno.test("responsesEndpoint appends the Responses API path", () => {
  const endpoint = responsesEndpoint("https://api.example.com");
  if (endpoint.href !== "https://api.example.com/v1/responses") {
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

Deno.test("gateway timeout and unavailability are actionable errors", () => {
  if (
    upstreamErrorKind(504, undefined, undefined, undefined) !==
      "provider_timeout"
  ) throw new Error("Expected gateway timeout classification");
  if (
    upstreamErrorKind(503, undefined, undefined, undefined) !==
      "provider_unavailable"
  ) throw new Error("Expected provider unavailability");
});

Deno.test("upstream transport deadline is distinct from an unreachable provider", () => {
  for (const name of ["TimeoutError", "AbortError"]) {
    if (
      !isUpstreamTimeout(new DOMException("do not expose request text", name))
    ) throw new Error("Expected timeout classification");
  }
  if (isUpstreamTimeout(new TypeError("connection refused"))) {
    throw new Error("Connection failure is not a timeout");
  }
  if (isUpstreamTimeout(null)) {
    throw new Error("Unknown errors are not timeouts");
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
