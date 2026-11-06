/**
 * VANDERY+ recurring membership. Separate from challenge `purchases`.
 *
 * Transition rules live here. `commit_vandery_plus_event` only checks the
 * checkout user, the idempotency key, and the allow-listed columns.
 * Fail closed: a missing form URL never falls back to a challenge form.
 */

import {
  httpUrlOrNull,
  invoiceTotalCents,
  isWebhookTokenValid,
  type FapiInvoice,
} from "./fapi.ts";

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

/**
 * paid_first and renew share one key per invoice so a retry does not add a
 * month. payment_failed, cancel, and refund keep their own keys, so a later
 * paid event for that invoice can still activate.
 */
export function eventKey(kind: string, invoiceId: string): string {
  const id = invoiceId.trim();
  if (kind === "paid_first" || kind === "renew") return `paid:${id}`;
  return `${kind}:${id}`;
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
    case "renew": {
      // The locked SQL function overwrites expires_at with
      // greatest(expires_at, now()) + interval '1 month'. This value is only
      // the in-memory preview.
      const expiresMs = Date.parse(row.expiresAt);
      const nowMs = Date.parse(event.now);
      const base = Number.isFinite(expiresMs) && expiresMs > nowMs
        ? row.expiresAt
        : event.now;
      return {
        status: "active",
        expires_at: addMonthsIso(base, 1),
        cancel_at_period_end: false,
        fapi_subscription_id: subscription,
        fapi_invoice_id: event.invoiceId,
        amount_cents: amount,
        currency,
      };
    }
    case "cancel":
      return { cancel_at_period_end: true };
    case "refund":
      return { status: "revoked", cancel_at_period_end: false };
    case "payment_failed":
      // An unpaid notice must not burn the pending checkout. A later paid
      // event for the same invoice still has to activate.
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

export const PROD_SUPABASE_PROJECT_REF = "yzmbxxgesnbsqygzgdky";

export function sandboxAllowed(
  flag: string | null | undefined,
  supabaseUrl?: string | null,
): boolean {
  if (flag !== "1") return false;
  if ((supabaseUrl ?? "").includes(PROD_SUPABASE_PROJECT_REF)) return false;
  return true;
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

/**
 * Real FAPI invoice shapes. See docs/vandery-plus/fapi-event-assumptions.md.
 * The invented `vandery_plus_event` custom field is ignored.
 */
export function isMembershipRefundInvoice(invoice: FapiInvoice): boolean {
  const type = String(invoice.type ?? "")
    .trim()
    .toLowerCase()
    .replaceAll("-", "_");
  if (type === "credit_note" || type === "dobropis") return true;
  const major = typeof invoice.total === "number"
    ? invoice.total
    : typeof invoice.total === "string" && invoice.total.trim()
    ? Number(invoice.total)
    : null;
  return major != null && Number.isFinite(major) && major < 0;
}

export function classifyFapiMembershipEvent(
  invoice: FapiInvoice,
  status: PlusStatus,
): PlusKind | null {
  if (isMembershipRefundInvoice(invoice)) return "refund";
  const type = String(invoice.type ?? "")
    .trim()
    .toLowerCase()
    .replaceAll("-", "_");
  if (type === "credit_note" || type === "dobropis") return "refund";
  if (
    invoice.cancelled === true || invoice.cancelled === 1 ||
    invoice.cancelled === "1" || invoice.cancelled === "true"
  ) {
    return "cancel";
  }
  const paid = invoice.paid === true || invoice.paid === 1 ||
    invoice.paid === "1" || invoice.paid === "true";
  if (!paid) {
    if (status === "pending" || status === "active") return "payment_failed";
    return null;
  }
  const parent = invoice.parent;
  const hasParent = parent != null && String(parent).trim() !== "" &&
    String(parent) !== "0";
  if (hasParent || status === "active" || status === "expired") return "renew";
  return "paid_first";
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

export type VanderyPlusProductConfig = {
  amountCents: number | null;
  itemIds: string[];
  formIds: string[];
  productIds: string[];
};

function splitIds(raw: string | null | undefined): string[] {
  if (!raw) return [];
  return raw
    .split(",")
    .map((part) => part.trim())
    .filter((part) => part.length > 0);
}

function parseCents(raw: string | null | undefined): number | null {
  if (!raw || !raw.trim()) return null;
  const value = Number(raw.trim());
  if (!Number.isInteger(value) || value < 0) return null;
  return value;
}

export function vanderyPlusProductConfigFromEnv(
  read: (key: string) => string | undefined,
): VanderyPlusProductConfig {
  return {
    amountCents: parseCents(read("FAPI_VANDERY_PLUS_AMOUNT_CENTS")),
    itemIds: splitIds(read("FAPI_VANDERY_PLUS_ITEM_ID")),
    formIds: splitIds(read("FAPI_VANDERY_PLUS_FORM_ID")),
    productIds: splitIds(read("FAPI_VANDERY_PLUS_PRODUCT_ID")),
  };
}

function idList(value: unknown): string[] {
  if (typeof value === "number" && Number.isFinite(value)) return [String(value)];
  if (typeof value === "string" && value.trim()) return [value.trim()];
  if (value && typeof value === "object" && "id" in value) {
    return idList((value as { id?: unknown }).id);
  }
  return [];
}

export function invoiceItemIds(invoice: FapiInvoice): string[] {
  const ids: string[] = [];
  for (const item of invoice.items ?? []) ids.push(...idList(item.id));
  return ids;
}

export function invoiceProductIds(invoice: FapiInvoice): string[] {
  const ids: string[] = [];
  for (const item of invoice.items ?? []) ids.push(...idList(item.code));
  return ids;
}

export function invoiceFormId(invoice: FapiInvoice): string | null {
  const ids = idList(invoice.form);
  return ids[0] ?? null;
}

/** Czech standard VAT. Assumption: configured price is gross, invoice.total may be net. */
export const VANDERY_PLUS_VAT_RATE = 0.21;

/** 1 CZK. Covers rounding between net and gross. */
export const VANDERY_PLUS_AMOUNT_TOLERANCE_CENTS = 100;

function withinCents(left: number, right: number): boolean {
  return Math.abs(left - right) <= VANDERY_PLUS_AMOUNT_TOLERANCE_CENTS;
}

/** True for an exact price, a 1 CZK rounding gap, or a 21% net/gross pair. */
export function amountsMatchNetOrGross(actual: number, expected: number): boolean {
  if (withinCents(actual, expected)) return true;
  const gross = (net: number) => Math.round(net * (1 + VANDERY_PLUS_VAT_RATE));
  const net = (grossAmount: number) =>
    Math.round(grossAmount / (1 + VANDERY_PLUS_VAT_RATE));
  return withinCents(actual, gross(expected)) ||
    withinCents(actual, net(expected)) ||
    withinCents(expected, gross(actual)) ||
    withinCents(expected, net(actual));
}

export type MembershipInvoiceOutcome =
  | { kind: "ok" }
  | { kind: "skip" }
  | {
    kind: "amount_mismatch";
    expectedCents: number | null;
    actualCents: number | null;
  };

/**
 * Notes are not proof of a VANDERY+ purchase. Ids must match.
 * Amount may differ by VAT net/gross or 1 CZK. A larger gap is amount_mismatch,
 * not a silent skip.
 */
export function membershipInvoiceOutcome(
  invoice: FapiInvoice,
  config: VanderyPlusProductConfig,
): MembershipInvoiceOutcome {
  const configured = config.itemIds.length + config.formIds.length +
    config.productIds.length;
  if (config.amountCents == null || configured === 0) return { kind: "skip" };
  if (
    config.itemIds.length > 0 &&
    !invoiceItemIds(invoice).some((id) => config.itemIds.includes(id))
  ) {
    return { kind: "skip" };
  }
  if (config.formIds.length > 0) {
    const formId = invoiceFormId(invoice);
    if (!formId || !config.formIds.includes(formId)) return { kind: "skip" };
  }
  if (
    config.productIds.length > 0 &&
    !invoiceProductIds(invoice).some((id) => config.productIds.includes(id))
  ) {
    return { kind: "skip" };
  }
  const amount = invoiceTotalCents(invoice);
  if (amount == null || !amountsMatchNetOrGross(amount, config.amountCents)) {
    return {
      kind: "amount_mismatch",
      expectedCents: config.amountCents,
      actualCents: amount,
    };
  }
  return { kind: "ok" };
}

export function membershipAmountAlert(input: {
  invoiceId: string | null;
  expectedCents: number | null;
  actualCents: number | null;
}): Record<string, unknown> {
  return {
    alert: "vandery_plus_amount_mismatch",
    invoiceId: input.invoiceId,
    expectedCents: input.expectedCents,
    actualCents: input.actualCents,
    tolerance: "vat_21_or_1_czk",
  };
}

/**
 * Notes are not proof of a VANDERY+ purchase. Amount and every configured
 * product id (item, form, product code) must match, with the net/gross tolerance.
 * Missing config fails closed.
 */
export function membershipProductMatches(
  invoice: FapiInvoice,
  config: VanderyPlusProductConfig,
): boolean {
  return membershipInvoiceOutcome(invoice, config).kind === "ok";
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
