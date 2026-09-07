import { ETORO_PUBLIC_API_BASE, type EtoroCredentials } from "./config";
import {
  EtoroAuthError,
  EtoroError,
  EtoroPayloadTooLargeError,
  EtoroPermissionError,
  EtoroRateLimitError,
  EtoroServerError,
} from "./errors";

/** UUID v4 generated per request — used for tracing on the eToro side. */
function requestId(): string {
  return crypto.randomUUID();
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Build the auth headers for a Public API request.
 *
 * The API accepts EITHER a Bearer token OR the `x-api-key` + `x-user-key` pair,
 * NEVER both — sending both is rejected even when each is independently valid.
 * Bearer takes precedence here.
 */
function authHeaders(creds: EtoroCredentials): Record<string, string> {
  if (creds.accessToken) {
    return { Authorization: `Bearer ${creds.accessToken}` };
  }
  if (creds.apiKey && creds.userKey) {
    return { "x-api-key": creds.apiKey, "x-user-key": creds.userKey };
  }
  throw new EtoroError("No eToro credentials configured");
}

export interface PublicApiRequest {
  path: string;
  method?: "GET" | "POST" | "PUT" | "DELETE";
  body?: unknown;
  /** Extra query string already assembled with literal commas where required. */
  query?: string;
}

/**
 * Thin client for the eToro Public API host (JSON bodies, free-form `{ error }`
 * envelope). Handles per-request `x-request-id` and the documented retry classes:
 *   429 -> backoff, same payload; 413/414 -> caller halves payload; 5xx -> backoff.
 */
export class EtoroPublicApiClient {
  constructor(
    private readonly creds: EtoroCredentials,
    private readonly maxRetries = 3,
  ) {}

  async request<T>({ path, method = "GET", body, query }: PublicApiRequest): Promise<T> {
    const url = `${ETORO_PUBLIC_API_BASE}${path}${query ? `?${query}` : ""}`;

    let attempt = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const headers: Record<string, string> = {
        ...authHeaders(this.creds),
        "x-request-id": requestId(),
        Accept: "application/json",
      };
      if (body !== undefined) headers["Content-Type"] = "application/json";

      let res: Response;
      try {
        res = await fetch(url, {
          method,
          headers,
          body: body !== undefined ? JSON.stringify(body) : undefined,
          cache: "no-store",
        });
      } catch (cause) {
        // Network-level failure. For trade-execution endpoints this would be an
        // ambiguous outcome (never retry); reads are safe to retry with backoff.
        if (attempt >= this.maxRetries) {
          throw new EtoroServerError(`Network error calling ${path}: ${String(cause)}`);
        }
        await sleep(backoffMs(attempt));
        attempt += 1;
        continue;
      }

      if (res.ok) {
        if (res.status === 204) return undefined as T;
        return (await res.json()) as T;
      }

      const errorText = await safeText(res);

      switch (res.status) {
        case 401:
          throw new EtoroAuthError(`401 from ${path}: ${errorText}`);
        case 403:
          throw new EtoroPermissionError(`403 from ${path}: ${errorText}`);
        case 413:
        case 414:
          // Caller must halve the payload; retrying the same size won't help.
          throw new EtoroPayloadTooLargeError(`${res.status} from ${path}: ${errorText}`);
        case 429:
          if (attempt >= this.maxRetries) {
            throw new EtoroRateLimitError(`429 from ${path}: ${errorText}`);
          }
          await sleep(backoffMs(attempt));
          attempt += 1;
          continue;
        default:
          if (res.status >= 500) {
            if (attempt >= this.maxRetries) {
              throw new EtoroServerError(`${res.status} from ${path}: ${errorText}`);
            }
            await sleep(backoffMs(attempt));
            attempt += 1;
            continue;
          }
          throw new EtoroError(`${res.status} from ${path}: ${errorText}`);
      }
    }
  }
}

function backoffMs(attempt: number): number {
  // Short exponential backoff with jitter: ~0.5s, 1s, 2s ...
  const base = 500 * 2 ** attempt;
  return base + Math.floor(Math.random() * 250);
}

async function safeText(res: Response): Promise<string> {
  try {
    return (await res.text()).slice(0, 500);
  } catch {
    return "<no body>";
  }
}
