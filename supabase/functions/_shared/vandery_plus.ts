/**
 * VANDERY+ recurring membership. Separate from challenge `purchases`.
 *
 * Transition rules live here. `commit_vandery_plus_event` only checks the
 * checkout user, the idempotency key, and the allow-listed columns.
 * Fail closed: a missing form URL never falls back to a challenge form.
 */

import { httpUrlOrNull, isWebhookTokenValid } from "./fapi.ts";

export const VANDERY_PLUS_PRODUCT = "vandery_plus";

export type PlusStatus =
  | "pending"
  | "active"
  | "expired"
  | "revoked"
  | "failed";

export type PlusKind =
  | "paid_first"
  | "renew"
  | "cancel"
  | "refund"
  | "payment_failed";

export type PlusRow = {
  id: string;
  userId: string;
  status: PlusStatus;
  startsAt: string | null;
  expiresAt: string;
  cancelAtPeriodEnd: boolean;
  fapiSubscriptionId: string | null;
  fapiInvoiceId: string | null;
  amountCents: number | null;
  currency: string | null;
};

export type PlusEvent = {
  kind: PlusKind;
  invoiceId: string;
  subscriptionId: string | null;
  /** User id written into the FAPI notes by checkout. Not the client body. */
  checkoutUserId: string;
  membershipId: string;
  /** Present only so callers can prove it is ignored. */
  clientBodyUserId?: string | null;
  amountCents?: number | null;
  currency?: string | null;
  now: string;
};

export type PlusPatch = Record<string, unknown>;

export function addMonthsIso(iso: string, months: number): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) {
    throw new Error("bad date");
  }
  const day = date.getUTCDate();
  date.setUTCDate(1);
  date.setUTCMonth(date.getUTCMonth() + months);
  const last = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0),
  ).getUTCDate();
  date.setUTCDate(Math.min(day, last));
  return date.toISOString();
}

export function eventKey(kind: string, invoiceId: string): string {
  return `${kind}:${invoiceId}`;
}

export function vanderyPlusNotes(userId: string, membershipId: string): string {
  return `viateria-plus:${userId}:${membershipId}`;
}

export function parseVanderyPlusNotes(
  notes: string | null | undefined,
): { userId: string; membershipId: string } | null {
  if (!notes) return null;
  const match = notes.trim().match(
    /^viateria-plus:([^:\s]+):([^:\s]+)$/,
  );
  if (!match) return null;
  return { userId: match[1], membershipId: match[2] };
}

/** Challenge notes stay on the purchase path. */
export function fapiProductRoute(
  notes: string | null | undefined,
): "membership" | "purchase" {
  if (parseVanderyPlusNotes(notes)) return "membership";
  return "purchase";
}

export function planVanderyPlusForm(
  formUrl: string | null | undefined,
): { ok: true; url: string } | { ok: false; status: number; error: string } {
  const url = httpUrlOrNull(formUrl);
  if (!url) {
    return { ok: false, status: 500, error: "fapi form url missing" };
  }
  return { ok: true, url };
}

export function vanderyPlusPrefillUrl(input: {
  formUrl: string;
  userId: string;
  membershipId: string;
  email?: string | null;
}): string {
  const url = new URL(input.formUrl);
  url.searchParams.set(
    "fapi-form-notes",
    vanderyPlusNotes(input.userId, input.membershipId),
  );
  if (input.email) url.searchParams.set("fapi-form-email", input.email);
  url.searchParams.delete("challenge_id");
  url.searchParams.delete("fapi-form-customField-challenge");
  return url.toString();
}

export function isMembershipActive(row: PlusRow, nowIso: string): boolean {
  return row.status === "active" &&
    Date.parse(row.expiresAt) > Date.parse(nowIso);
}

/**
 * Next row patch. Does not read `clientBodyUserId`.
 * Caller must reject when `checkoutUserId` is not `row.userId` before commit.
 */
export function nextMembershipPatch(
  row: PlusRow,
  event: PlusEvent,
): PlusPatch {
  const amount = event.amountCents ?? row.amountCents;
  const currency = event.currency ?? row.currency;
  const subscription = event.subscriptionId ?? row.fapiSubscriptionId;
  switch (event.kind) {
    case "paid_first":
      return {
        status: "active",
        starts_at: row.startsAt ?? event.now,
        expires_at: addMonthsIso(event.now, 1),
        cancel_at_period_end: false,
        fapi_subscription_id: subscription,
        fapi_invoice_id: event.invoiceId,
        amount_cents: amount,
        currency,
      };
    case "renew":
      return {
        status: "active",
        expires_at: addMonthsIso(row.expiresAt, 1),
        cancel_at_period_end: false,
        fapi_subscription_id: subscription,
        fapi_invoice_id: event.invoiceId,
        amount_cents: amount,
        currency,
      };
    case "cancel":
      return { cancel_at_period_end: true };
    case "refund":
      return { status: "revoked", cancel_at_period_end: false };
    case "payment_failed":
      if (row.status === "pending") return { status: "failed" };
      return {};
  }
}

export type PlusStore = {
  load(id: string): Promise<PlusRow | null>;
  commit(input: {
    membershipId: string;
    userId: string;
    key: string;
    kind: PlusKind;
    invoiceId: string;
    patch: PlusPatch;
  }): Promise<{ idempotent: boolean; row: PlusRow }>;
};

export type DeliveryResult = {
  status: number;
  body: Record<string, unknown>;
  wrote: boolean;
  row: PlusRow | null;
};

export async function deliverVanderyPlus(
  store: PlusStore,
  event: PlusEvent,
): Promise<DeliveryResult> {
  const row = await store.load(event.membershipId);
  if (!row) {
    return {
      status: 409,
      body: { status: "FAILED", message: "no checkout session" },
      wrote: false,
      row: null,
    };
  }
  // Ignore event.clientBodyUserId. The checkout row is the only target.
  if (event.checkoutUserId !== row.userId) {
    return {
      status: 409,
      body: { status: "FAILED", message: "user mismatch" },
      wrote: false,
      row,
    };
  }
  const patch = nextMembershipPatch(row, event);
  const committed = await store.commit({
    membershipId: row.id,
    userId: row.userId,
    key: eventKey(event.kind, event.invoiceId),
    kind: event.kind,
    invoiceId: event.invoiceId,
    patch,
  });
  return {
    status: 200,
    body: {
      status: "OK",
      idempotent: committed.idempotent,
      membership_status: committed.row.status,
      expires_at: committed.row.expiresAt,
      cancel_at_period_end: committed.row.cancelAtPeriodEnd,
    },
    wrote: !committed.idempotent && Object.keys(patch).length > 0,
    row: committed.row,
  };
}

export function webhookTokenGate(
  secret: string | null | undefined,
  token: string | null | undefined,
): "ok" | "reject" {
  return isWebhookTokenValid(secret, token) ? "ok" : "reject";
}

export function sandboxAllowed(flag: string | null | undefined): boolean {
  return flag === "1";
}

export function isPlusKind(value: unknown): value is PlusKind {
  return value === "paid_first" ||
    value === "renew" ||
    value === "cancel" ||
    value === "refund" ||
    value === "payment_failed";
}

export function plusRowFromDb(raw: Record<string, unknown>): PlusRow | null {
  const id = stringOrNull(raw.id);
  const userId = stringOrNull(raw.user_id);
  const status = raw.status;
  const expiresAt = stringOrNull(raw.expires_at);
  if (!id || !userId || !expiresAt || !isPlusStatus(status)) return null;
  return {
    id,
    userId,
    status,
    startsAt: stringOrNull(raw.starts_at),
    expiresAt,
    cancelAtPeriodEnd: raw.cancel_at_period_end === true,
    fapiSubscriptionId: stringOrNull(raw.fapi_subscription_id),
    fapiInvoiceId: stringOrNull(raw.fapi_invoice_id),
    amountCents: typeof raw.amount_cents === "number" ? raw.amount_cents : null,
    currency: stringOrNull(raw.currency),
  };
}

function isPlusStatus(value: unknown): value is PlusStatus {
  return value === "pending" ||
    value === "active" ||
    value === "expired" ||
    value === "revoked" ||
    value === "failed";
}

function stringOrNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

export function applyPatch(row: PlusRow, patch: PlusPatch): PlusRow {
  const next: PlusRow = { ...row };
  if (typeof patch.status === "string" && isPlusStatus(patch.status)) {
    next.status = patch.status;
  }
  if (typeof patch.starts_at === "string") next.startsAt = patch.starts_at;
  if (typeof patch.expires_at === "string") next.expiresAt = patch.expires_at;
  if (typeof patch.cancel_at_period_end === "boolean") {
    next.cancelAtPeriodEnd = patch.cancel_at_period_end;
  }
  if (patch.fapi_subscription_id === null ||
    typeof patch.fapi_subscription_id === "string") {
    next.fapiSubscriptionId = patch.fapi_subscription_id as string | null;
  }
  if (typeof patch.fapi_invoice_id === "string") {
    next.fapiInvoiceId = patch.fapi_invoice_id;
  }
  if (typeof patch.amount_cents === "number") next.amountCents = patch.amount_cents;
  if (typeof patch.currency === "string") next.currency = patch.currency;
  return next;
}

export type CheckoutDeps = {
  formUrl: string | null;
  userId: string;
  email?: string | null;
  now: string;
  loadByUser: (userId: string) => Promise<PlusRow | null>;
  insertPending: (userId: string, expiresAt: string) => Promise<PlusRow>;
  markPending: (row: PlusRow, expiresAt: string) => Promise<PlusRow>;
};

export async function startVanderyPlusCheckout(
  deps: CheckoutDeps,
): Promise<{ status: number; body: Record<string, unknown> }> {
  const plan = planVanderyPlusForm(deps.formUrl);
  if (!plan.ok) {
    return { status: plan.status, body: { error: plan.error } };
  }
  const existing = await deps.loadByUser(deps.userId);
  if (existing && isMembershipActive(existing, deps.now)) {
    return { status: 409, body: { error: "already_active" } };
  }
  const row = existing
    ? await deps.markPending(existing, deps.now)
    : await deps.insertPending(deps.userId, deps.now);
  if (row.userId !== deps.userId) {
    return { status: 500, body: { error: "checkout user mismatch" } };
  }
  const url = vanderyPlusPrefillUrl({
    formUrl: plan.url,
    userId: deps.userId,
    membershipId: row.id,
    email: deps.email,
  });
  if (new URL(url).searchParams.has("challenge_id")) {
    return { status: 500, body: { error: "challenge_id not allowed" } };
  }
  return { status: 200, body: { url } };
}

export function inferKind(input: {
  explicit: string | null;
  invoicePaid: boolean;
  status: PlusStatus;
}): PlusKind | null {
  if (isPlusKind(input.explicit)) return input.explicit;
  if (!input.invoicePaid) return null;
  if (input.status === "active") return "renew";
  return "paid_first";
}

/** Sandbox JSON only. A challenge invoice body returns null and stays on purchases. */
export function parseSandboxEvent(body: string): PlusEvent | null {
  let json: Record<string, unknown>;
  try {
    const parsed = JSON.parse(body) as unknown;
    if (!parsed || typeof parsed !== "object") return null;
    json = parsed as Record<string, unknown>;
  } catch {
    return null;
  }
  if (json.product !== VANDERY_PLUS_PRODUCT || !isPlusKind(json.event)) {
    return null;
  }
  const invoiceId = typeof json.invoice_id === "string" ? json.invoice_id.trim() : "";
  const membershipId = typeof json.membership_id === "string"
    ? json.membership_id.trim()
    : "";
  const checkoutUserId = typeof json.checkout_user_id === "string"
    ? json.checkout_user_id.trim()
    : "";
  if (!invoiceId || !membershipId || !checkoutUserId) return null;
  return {
    kind: json.event,
    invoiceId,
    subscriptionId: typeof json.subscription_id === "string"
      ? json.subscription_id
      : null,
    checkoutUserId,
    membershipId,
    clientBodyUserId: typeof json.client_body_user_id === "string"
      ? json.client_body_user_id
      : null,
    amountCents: typeof json.amount_cents === "number" ? json.amount_cents : null,
    currency: typeof json.currency === "string" ? json.currency : null,
    now: typeof json.now === "string" ? json.now : new Date().toISOString(),
  };
}

export function invoiceCustomField(
  fields: { name?: unknown; value?: unknown }[] | null | undefined,
  name: string,
): string | null {
  const want = name.toLowerCase();
  for (const field of fields ?? []) {
    const fieldName = String(field.name ?? "").trim().toLowerCase();
    const value = String(field.value ?? "").trim();
    if (fieldName === want && value) return value;
  }
  return null;
}
