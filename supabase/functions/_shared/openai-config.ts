export const defaultOpenAIBaseURL = "https://api.openai.com";
export const defaultOpenAIModel = "gpt-5.6-luna";
export const defaultReasoningEffort = "medium";

const reasoningEfforts = new Set([
  "none",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
]);

export function responsesEndpoint(baseURL: string): URL {
  const endpoint = new URL(baseURL.trim());
  const isLoopback = endpoint.hostname === "localhost" ||
    endpoint.hostname === "127.0.0.1";
  if (endpoint.protocol !== "https:" && !isLoopback) {
    throw new Error("OPENAI_BASE_URL must use HTTPS");
  }

  const path = endpoint.pathname.replace(/\/+$/, "");
  if (path.endsWith("/v1/responses")) {
    endpoint.pathname = path;
  } else if (path.endsWith("/v1")) {
    endpoint.pathname = `${path}/responses`;
  } else {
    endpoint.pathname = `${path}/v1/responses`;
  }
  endpoint.search = "";
  endpoint.hash = "";
  return endpoint;
}

export function reasoningEffort(value: string | undefined): string {
  const normalized = value?.trim().toLowerCase();
  return normalized && reasoningEfforts.has(normalized)
    ? normalized
    : defaultReasoningEffort;
}

export function upstreamErrorKind(
  status: number,
  code: unknown,
  type: unknown,
  message: unknown,
): string {
  if (status === 401 || status === 403) {
    return "provider_authentication_failed";
  }
  if (status === 429) {
    return "provider_rate_limited";
  }

  const description = [code, type, message]
    .filter((value): value is string => typeof value === "string")
    .join(" ");
  const modelFailure =
    /model.{0,40}(not support|unsupported|not found|does not exist|unknown)|(?:unsupported|invalid).{0,20}model/i;
  return modelFailure.test(description)
    ? "model_not_supported"
    : "openai_error";
}
