/**
 * FAPI (fapi.cz) helpers shared by `start-fapi-checkout` and `fapi-webhook`.
 *
 * Official invoice-notification security (https://web.fapi.cz/api-doc/):
 *   sha1( time + invoice.id + invoice.number + Σ md5(item.id + item.name) )
 * matching `Fapi\FapiClient\Tools\SecurityChecker::isInvoiceSecurityValid`.
 *
 * Form prefill (https://napoveda.fapi.cz/article/46-predvyplneni-prodejniho-formulare):
 *   fapi-form-notes, fapi-form-email, fapi-form-customField-{id}
 */

import { crypto } from "jsr:@std/crypto@1.0.4";
import { encodeHex } from "jsr:@std/encoding@1.0.10/hex";

export const FAPI_API_BASE = "https://api.fapi.cz";

export type RewardVariant = "diploma" | "medal_and_diploma";

export type FapiInvoiceItem = {
  id?: unknown;
  name?: unknown;
};

export type FapiCustomField = {
  name?: unknown;
  value?: unknown;
};

export type FapiInvoice = {
  id?: unknown;
  number?: unknown;
  paid?: unknown;
  type?: unknown;
  notes?: unknown;
  clients_note?: unknown;
  client_note?: unknown;
  /** FAPI client id (integer on the wire). */
  client?: unknown;
  /** Invoice total in major units of [currency] (199.00 CZK → 199). */
  total?: unknown;
  currency?: unknown;
  custom_fields?: FapiCustomField[] | null;
  items?: FapiInvoiceItem[] | null;
};

export function parseRewardVariant(raw: unknown): RewardVariant {
  return raw === "medal_and_diploma" || raw === "medalAndDiploma"
    ? "medal_and_diploma"
    : "diploma";
}

export function httpUrlOrNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  try {
    const url = new URL(trimmed);
    if (url.protocol !== "http:" && url.protocol !== "https:") return null;
    return trimmed;
  } catch {
    return null;
  }
}

/** Compact payload stored in FAPI notes so the webhook can match a purchase. */
export function viateriaNotes(
  userId: string,
  challengeId: string,
  rewardVariant: RewardVariant,
): string {
  return `viateria:${userId}:${challengeId}:${rewardVariant}`;
}

export function parseViateriaNotes(
  notes: string | null | undefined,
): {
  userId: string;
  challengeId: string;
  rewardVariant: RewardVariant;
} | null {
  if (!notes) return null;
  const match = notes.trim().match(
    /^viateria:([^:\s]+):([^:\s]+):(diploma|medal_and_diploma|medalAndDiploma)$/,
  );
  if (!match) return null;
  return {
    userId: match[1],
    challengeId: match[2],
    rewardVariant: parseRewardVariant(match[3]),
  };
}

export function appendFapiPrefill(
  formUrl: string,
  params: Record<string, string | undefined>,
): string {
  const url = new URL(formUrl);
  for (const [key, value] of Object.entries(params)) {
    if (value != null && value !== "") url.searchParams.set(key, value);
  }
  return url.toString();
}

export function fapiPrefillParams(input: {
  userId: string;
  challengeId: string;
  rewardVariant: RewardVariant;
  email?: string | null;
  customFieldIdUser?: string | null;
  customFieldIdChallenge?: string | null;
  customFieldIdReward?: string | null;
}): Record<string, string | undefined> {
  const notes = viateriaNotes(
    input.userId,
    input.challengeId,
    input.rewardVariant,
  );
  const params: Record<string, string | undefined> = {
    "fapi-form-notes": notes,
    "fapi-form-email": input.email ?? undefined,
  };
  if (input.customFieldIdUser) {
    params[`fapi-form-customField-${input.customFieldIdUser}`] = input.userId;
  }
  if (input.customFieldIdChallenge) {
    params[`fapi-form-customField-${input.customFieldIdChallenge}`] =
      input.challengeId;
  }
  if (input.customFieldIdReward) {
    params[`fapi-form-customField-${input.customFieldIdReward}`] =
      input.rewardVariant;
  }
  return params;
}

async function hexDigest(
  algorithm: "MD5" | "SHA-1",
  text: string,
): Promise<string> {
  const digest = await crypto.subtle.digest(
    algorithm,
    new TextEncoder().encode(text),
  );
  return encodeHex(digest);
}

export async function invoiceSecurityHash(
  invoice: FapiInvoice,
  time: number | string,
): Promise<string | null> {
  const id = invoice.id;
  const number = invoice.number;
  if (id == null || number == null) return null;
  let itemsSecurityHash = "";
  for (const item of invoice.items ?? []) {
    itemsSecurityHash += await hexDigest(
      "MD5",
      `${item.id ?? ""}${item.name ?? ""}`,
    );
  }
  return await hexDigest("SHA-1", `${time}${id}${number}${itemsSecurityHash}`);
}

export async function isInvoiceSecurityValid(
  invoice: FapiInvoice,
  time: number | string,
  expectedSecurity: string,
): Promise<boolean> {
  const actual = await invoiceSecurityHash(invoice, time);
  if (actual == null || !expectedSecurity) return false;
  return timingSafeEqual(actual, expectedSecurity);
}

/** Case-sensitive constant-time compare. A length mismatch returns false. */
export function timingSafeEqualExact(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

function timingSafeEqual(a: string, b: string): boolean {
  return timingSafeEqualExact(a.toLowerCase(), b.toLowerCase());
}

/**
 * Shared-secret gate for `fapi-webhook`.
 * Missing secret, missing token, or a mismatch all fail. Never treats an
 * empty secret as "check skipped".
 */
export function isWebhookTokenValid(
  secret: string | null | undefined,
  token: string | null | undefined,
): boolean {
  if (secret == null || secret.length === 0) return false;
  if (token == null || token.length === 0) return false;
  return timingSafeEqualExact(secret, token);
}

export type PurchaseUnlockPlan = "already_paid" | "mark_paid" | "reject";

/**
 * Paid unlock only updates an existing pending row.
 * An already-paid row is an idempotent replay. Anything else (no row,
 * failed, refunded) must not insert a paid purchase.
 */
export function purchaseUnlockPlan(
  existing: { status?: string | null } | null | undefined,
): PurchaseUnlockPlan {
  const status = existing?.status;
  if (status === "paid") return "already_paid";
  if (status === "pending") return "mark_paid";
  return "reject";
}

/** Catalog readability RPC: only a literal true with no error may proceed. */
export function callerCanReadChallenge(
  readable: unknown,
  rpcError: unknown,
): boolean {
  return rpcError == null && readable === true;
}

const USER_FIELD_NAMES = ["user_id", "userid", "viateria_user_id"];
const CHALLENGE_FIELD_NAMES = [
  "challenge_id",
  "challengeid",
  "viateria_challenge_id",
];
const VARIANT_FIELD_NAMES = [
  "reward_variant",
  "rewardvariant",
  "viateria_reward_variant",
];

function customFieldValue(
  invoice: FapiInvoice,
  names: string[],
): string | undefined {
  const want = new Set(names.map((name) => name.toLowerCase()));
  for (const field of invoice.custom_fields ?? []) {
    const name = String(field.name ?? "").trim().toLowerCase();
    const value = field.value == null ? "" : String(field.value).trim();
    if (want.has(name) && value) return value;
  }
  return undefined;
}

export function purchaseKeysFromInvoice(invoice: FapiInvoice): {
  userId?: string;
  challengeId?: string;
  rewardVariant?: RewardVariant;
} {
  const fromNotes = parseViateriaNotes(
    firstString(
      invoice.notes,
      invoice.clients_note,
      invoice.client_note,
    ),
  );
  const userId =
    customFieldValue(invoice, USER_FIELD_NAMES) ?? fromNotes?.userId;
  const challengeId =
    customFieldValue(invoice, CHALLENGE_FIELD_NAMES) ?? fromNotes?.challengeId;
  const rewardRaw = customFieldValue(invoice, VARIANT_FIELD_NAMES);
  const rewardVariant = rewardRaw
    ? parseRewardVariant(rewardRaw)
    : fromNotes?.rewardVariant;
  return { userId, challengeId, rewardVariant };
}

function firstString(...values: unknown[]): string | undefined {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) return value;
  }
  return undefined;
}

export function parseNotification(body: string, contentType: string | null): {
  invoiceId?: string;
  time?: string;
  security?: string;
} {
  const trimmed = body.trim();
  if (!trimmed) return {};
  const asJson = contentType?.includes("application/json") ||
    trimmed.startsWith("{");
  if (asJson) {
    try {
      const json = JSON.parse(trimmed) as Record<string, unknown>;
      return {
        invoiceId: stringish(json.id ?? json.invoice),
        time: stringish(json.time),
        security: stringish(json.security),
      };
    } catch {
      // Fall through to form parsing.
    }
  }
  const params = new URLSearchParams(trimmed);
  return {
    invoiceId: stringish(params.get("id") ?? params.get("invoice")),
    time: stringish(params.get("time")),
    security: stringish(params.get("security")),
  };
}

function stringish(value: unknown): string | undefined {
  if (value == null) return undefined;
  const text = String(value).trim();
  return text ? text : undefined;
}

export function fapiInvoiceId(invoice: FapiInvoice): string | null {
  return stringish(invoice.id) ?? null;
}

export function fapiClientId(invoice: FapiInvoice): string | null {
  return stringish(invoice.client) ?? null;
}

/** Lowercase ISO currency from the invoice. Empty or non-3-letter → null. */
export function invoiceCurrencyCode(invoice: FapiInvoice): string | null {
  const raw = stringish(invoice.currency);
  if (!raw) return null;
  const code = raw.toLowerCase();
  if (!/^[a-z]{3}$/.test(code)) return null;
  return code;
}

/**
 * `invoice.total` is major currency units. Purchases store integer cents
 * (199.00 CZK → 19900), matching `challenges.*_price_cents`.
 */
export function invoiceTotalCents(invoice: FapiInvoice): number | null {
  const major = finiteNumber(invoice.total);
  if (major == null || major < 0) return null;
  return Math.round(major * 100);
}

function finiteNumber(value: unknown): number | null {
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

export async function fetchFapiInvoice(
  invoiceId: string,
  username: string,
  apiKey: string,
  apiBase = FAPI_API_BASE,
): Promise<FapiInvoice> {
  const auth = btoa(`${username}:${apiKey}`);
  const response = await fetch(
    `${apiBase.replace(/\/$/, "")}/invoices/${encodeURIComponent(invoiceId)}`,
    {
      headers: {
        Accept: "application/json",
        Authorization: `Basic ${auth}`,
      },
    },
  );
  if (!response.ok) {
    throw new Error(`fapi invoice ${invoiceId} http ${response.status}`);
  }
  return await response.json() as FapiInvoice;
}

export type PromoTargetType = "all" | "user" | "segment" | "locale" | "country";

export type PromoAssignment = {
  targetType: PromoTargetType;
  userId?: string | null;
  segmentId?: string | null;
  locale?: string | null;
  countryCode?: string | null;
};

export type PromoViewer = {
  userId: string;
  locale?: string | null;
  countryCode?: string | null;
  segmentIds: ReadonlySet<string>;
};

export type DiscountStripe = {
  id: string;
  sortOrder: number;
  startsAt: string | null;
  endsAt: string | null;
  promoDiplomaPriceCents: number | null;
  promoMedalPriceCents: number | null;
  assignments: PromoAssignment[];
};

/** Zero assignments means everyone. Otherwise any one row is enough. */
export function promoMatchesViewer(
  assignments: PromoAssignment[],
  viewer: PromoViewer,
): boolean {
  if (assignments.length === 0) return true;
  return assignments.some((assignment) => {
    switch (assignment.targetType) {
      case "all":
        return true;
      case "user":
        return assignment.userId != null && assignment.userId === viewer.userId;
      case "segment":
        return assignment.segmentId != null &&
          viewer.segmentIds.has(assignment.segmentId);
      case "locale":
        return viewer.locale != null &&
          viewer.locale.length > 0 &&
          assignment.locale === viewer.locale;
      case "country": {
        const viewerCode = viewer.countryCode?.trim().toUpperCase();
        const targetCode = assignment.countryCode?.trim().toUpperCase();
        return viewerCode != null &&
          viewerCode.length > 0 &&
          viewerCode === targetCode;
      }
    }
  });
}

export function isStripeInWindow(
  stripe: { startsAt: string | null; endsAt: string | null },
  now: Date,
): boolean {
  if (stripe.startsAt && Date.parse(stripe.startsAt) > now.getTime()) {
    return false;
  }
  if (stripe.endsAt && Date.parse(stripe.endsAt) < now.getTime()) {
    return false;
  }
  return true;
}

/** Lowest sort_order, then id, among in-window stripes the viewer matches. */
export function selectActiveDiscountStripe(
  stripes: DiscountStripe[],
  viewer: PromoViewer,
  now: Date,
): DiscountStripe | null {
  const matches = stripes
    .filter((stripe) => isStripeInWindow(stripe, now))
    .filter((stripe) => promoMatchesViewer(stripe.assignments, viewer))
    .sort((a, b) => a.sortOrder - b.sortOrder || a.id.localeCompare(b.id));
  return matches[0] ?? null;
}

/**
 * Prefer a discount stripe price when it is set (including 0).
 * Null promo prices keep the challenge SKU.
 */
export function checkoutAmountCents(options: {
  isMedal: boolean;
  diplomaPriceCents: number;
  medalPriceCents: number;
  promoDiplomaPriceCents?: number | null;
  promoMedalPriceCents?: number | null;
}): number {
  const fallback = options.isMedal
    ? options.medalPriceCents
    : options.diplomaPriceCents;
  const promo = options.isMedal
    ? options.promoMedalPriceCents
    : options.promoDiplomaPriceCents;
  return promo ?? fallback;
}

export function webhookTokenFromRequest(req: Request): string | null {
  const url = new URL(req.url);
  return (
    url.searchParams.get("token") ??
    req.headers.get("x-fapi-webhook-token")
  );
}
