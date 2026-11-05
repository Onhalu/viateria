/** Normalize a redemption code: upper, trim, strip spaces and dashes. */
const CODE = /^[A-Z0-9]{8,16}$/;

export function normalizeCode(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  if (raw.length > 64) return null;
  const stripped = raw.trim().toUpperCase().replace(/[\s-]+/g, "");
  if (!CODE.test(stripped)) return null;
  return stripped;
}

export async function hashCode(normalized: string): Promise<string> {
  const bytes = new TextEncoder().encode(normalized);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function redeemHttpStatus(error: string): number {
  if (error === "email_mismatch") return 403;
  if (error === "rate_limited") return 429;
  if (error === "unauthorized") return 401;
  return 400;
}

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID.test(value);
}
