import { ETORO_SSO_BASE, getSsoConfig } from "./config";

/**
 * eToro SSO / OAuth helpers.
 *
 * The SSO host is DISTINCT from the Public API host: requests are
 * `application/x-www-form-urlencoded` (sending JSON yields empty-body 400s) and
 * the error envelope is OAuth-style `{ error, error_description }`.
 */

const AUTHORIZE_URL = `${ETORO_SSO_BASE}/oidc/auth`;
const TOKEN_URL = `${ETORO_SSO_BASE}/oidc/token`;

function base64UrlEncode(bytes: Uint8Array): string {
  let str = "";
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function createPkcePair(): { verifier: string; challenge: string } {
  const verifierBytes = crypto.getRandomValues(new Uint8Array(32));
  const verifier = base64UrlEncode(verifierBytes);
  return { verifier, challenge: verifier };
}

/** SHA-256 based S256 PKCE challenge from a verifier. */
export async function s256Challenge(verifier: string): Promise<string> {
  const data = new TextEncoder().encode(verifier);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return base64UrlEncode(new Uint8Array(digest));
}

export function buildAuthorizeUrl(params: {
  state: string;
  codeChallenge: string;
  scope?: string;
}): string {
  const sso = getSsoConfig();
  const qs = new URLSearchParams({
    response_type: "code",
    client_id: sso.clientId ?? "",
    redirect_uri: sso.redirectUri ?? "",
    scope: params.scope ?? "openid profile trading",
    state: params.state,
    code_challenge: params.codeChallenge,
    code_challenge_method: "S256",
  });
  return `${AUTHORIZE_URL}?${qs.toString()}`;
}

export interface TokenResponse {
  access_token: string;
  refresh_token?: string;
  expires_in?: number;
  token_type?: string;
}

/**
 * Exchange an auth code for tokens. Form-encoded per the SSO contract. Refresh
 * tokens rotate on every exchange — callers must persist the new one atomically.
 */
export async function exchangeCode(params: {
  code: string;
  codeVerifier: string;
}): Promise<TokenResponse> {
  const sso = getSsoConfig();
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    code: params.code,
    redirect_uri: sso.redirectUri ?? "",
    client_id: sso.clientId ?? "",
    code_verifier: params.codeVerifier,
  });
  if (sso.clientSecret) body.set("client_secret", sso.clientSecret);

  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
    cache: "no-store",
  });

  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    throw new Error(`SSO token exchange failed (${res.status}): ${detail}`);
  }
  return (await res.json()) as TokenResponse;
}
