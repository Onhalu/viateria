/**
 * Browser CORS for Edge Functions.
 *
 * Allow-list comes from ALLOWED_ORIGINS (comma-separated absolute origins).
 * A request origin that is not allowed gets no Access-Control-Allow-Origin
 * header — never `*`. Localhost / loopback origins are accepted only when
 * the function is not running in production.
 *
 * Production is explicit ENVIRONMENT/SUPABASE_ENV of `production` or `prod`,
 * or any non-local SUPABASE_URL when ENVIRONMENT is unset. Local Supabase
 * (`127.0.0.1`, `localhost`, `kong`) is not production. `local`,
 * `development`, `test`, and `staging` are not production either.
 */

const LOOPBACK_HOSTS = new Set(["localhost", "127.0.0.1", "::1"]);

export const CORS_ALLOW_HEADERS =
  "authorization, x-client-info, apikey, content-type";

export const CORS_ALLOW_METHODS = "POST, OPTIONS";

export type EnvSource = {
  get(name: string): string | undefined;
};

export type CorsConfig = {
  allowedOrigins: readonly string[];
  production: boolean;
};

export function isProductionRuntime(env: EnvSource = Deno.env): boolean {
  const explicit = (env.get("ENVIRONMENT") ?? env.get("SUPABASE_ENV") ?? "")
    .trim()
    .toLowerCase();
  if (explicit === "production" || explicit === "prod") return true;
  if (
    explicit === "local" ||
    explicit === "development" ||
    explicit === "dev" ||
    explicit === "test" ||
    explicit === "staging"
  ) {
    return false;
  }

  const supabaseUrl = env.get("SUPABASE_URL") ?? "";
  if (!supabaseUrl) return true;
  try {
    const host = new URL(supabaseUrl).hostname.replace(/^\[|\]$/g, "")
      .toLowerCase();
    return !LOOPBACK_HOSTS.has(host) && host !== "kong";
  } catch {
    return true;
  }
}

/** Canonical `scheme://host[:port]`, or null when [value] is not an http(s) origin. */
export function canonicalOrigin(value: string): string | null {
  const trimmed = value.trim();
  if (!trimmed || /[\s\r\n]/.test(trimmed)) return null;
  try {
    const url = new URL(trimmed);
    if (url.protocol !== "http:" && url.protocol !== "https:") return null;
    if (url.username || url.password) return null;
    return url.origin;
  } catch {
    return null;
  }
}

export function parseAllowedOrigins(raw: string | undefined): string[] {
  if (!raw) return [];
  const origins: string[] = [];
  for (const part of raw.split(",")) {
    const origin = canonicalOrigin(part);
    if (origin && !origins.includes(origin)) origins.push(origin);
  }
  return origins;
}

export function corsConfigFromEnv(env: EnvSource = Deno.env): CorsConfig {
  return {
    allowedOrigins: parseAllowedOrigins(env.get("ALLOWED_ORIGINS")),
    production: isProductionRuntime(env),
  };
}

export function isLocalhostOrigin(origin: string): boolean {
  const canonical = canonicalOrigin(origin);
  if (!canonical) return false;
  try {
    const host = new URL(canonical).hostname.replace(/^\[|\]$/g, "")
      .toLowerCase();
    return LOOPBACK_HOSTS.has(host);
  } catch {
    return false;
  }
}

/**
 * Localhost is allowed only outside production, even if it was copied into
 * ALLOWED_ORIGINS. Every other origin must be on the allow-list.
 */
export function isOriginAllowed(
  origin: string | null,
  config: CorsConfig,
): boolean {
  if (!origin) return false;
  const canonical = canonicalOrigin(origin);
  if (!canonical) return false;
  if (isLocalhostOrigin(canonical)) return !config.production;
  return config.allowedOrigins.includes(canonical);
}

export function corsHeaders(
  req: Request,
  config: CorsConfig = corsConfigFromEnv(),
): Headers {
  const headers = new Headers();
  headers.set("Vary", "Origin");
  const origin = req.headers.get("Origin");
  if (origin && isOriginAllowed(origin, config)) {
    headers.set("Access-Control-Allow-Origin", origin);
  }
  headers.set("Access-Control-Allow-Headers", CORS_ALLOW_HEADERS);
  headers.set("Access-Control-Allow-Methods", CORS_ALLOW_METHODS);
  return headers;
}

/** Preflight is 204 for every caller. Disallowed origins still omit ACAO. */
export function preflightResponse(
  req: Request,
  config: CorsConfig = corsConfigFromEnv(),
): Response {
  return new Response(null, {
    status: 204,
    headers: corsHeaders(req, config),
  });
}
