import type { EtoroEnvironment } from "./types";

/**
 * Runtime configuration for the eToro integration.
 *
 * Two distinct hosts are used with different content types and error envelopes —
 * they cannot share a client wrapper (see the eToro API conventions).
 */
export const ETORO_PUBLIC_API_BASE = "https://public-api.etoro.com/api/v1";
export const ETORO_SSO_BASE = "https://www.etoro.com/sso";

export interface EtoroCredentials {
  /** Bearer access token (SSO auth). Mutually exclusive with the API-key pair. */
  accessToken?: string;
  /** Partner API key (`x-api-key`). Pairs with `userKey`. */
  apiKey?: string;
  /** Per-user key (`x-user-key`). Pairs with `apiKey`. */
  userKey?: string;
}

export interface EtoroSsoConfig {
  clientId?: string;
  clientSecret?: string;
  redirectUri?: string;
}

function env(name: string): string | undefined {
  const v = process.env[name];
  return v && v.trim().length > 0 ? v.trim() : undefined;
}

export function getCredentials(): EtoroCredentials {
  return {
    accessToken: env("ETORO_ACCESS_TOKEN"),
    apiKey: env("ETORO_API_KEY"),
    userKey: env("ETORO_USER_KEY"),
  };
}

export function getSsoConfig(): EtoroSsoConfig {
  return {
    clientId: env("ETORO_CLIENT_ID"),
    clientSecret: env("ETORO_CLIENT_SECRET"),
    redirectUri: env("ETORO_REDIRECT_URI"),
  };
}

export function getEnvironment(): EtoroEnvironment {
  return env("ETORO_ENV") === "real" ? "real" : "demo";
}

/**
 * The app runs in demo mode (serving realistic mock account data through the
 * real code paths) when no eToro credentials are configured, or when explicitly
 * forced with `VIATERIA_DEMO=true`. This lets the dashboard render end-to-end
 * without live secrets; add `ETORO_*` secrets to switch to live data.
 */
export function isDemoMode(): boolean {
  if (env("VIATERIA_DEMO") === "true") return true;
  if (env("VIATERIA_DEMO") === "false") return false;
  const creds = getCredentials();
  const hasBearer = Boolean(creds.accessToken);
  const hasKeyPair = Boolean(creds.apiKey && creds.userKey);
  return !hasBearer && !hasKeyPair;
}

/** True when SSO ("Sign in with eToro") is fully configured. */
export function isSsoConfigured(): boolean {
  const sso = getSsoConfig();
  return Boolean(sso.clientId && sso.redirectUri);
}
