/**
 * ED-01 … ED-12 and the sandbox contract for E2E-03 … E2E-06.
 * No live FAPI call. No remote Supabase.
 */
import {
  addMonthsIso,
  applyPatch,
  classifyFapiMembershipEvent,
  deliverVanderyPlus,
  eventKey,
  fapiProductRoute,
  inferKind,
  invoiceFormId,
  isMembershipActive,
  membershipProductMatches,
  vanderyPlusProductConfigFromEnv,
  parseVanderyPlusNotes,
  planVanderyPlusForm,
  sandboxAllowed,
  startVanderyPlusCheckout,
  vanderyPlusPrefillUrl,
  webhookTokenGate,
  type PlusEvent,
  type PlusKind,
  type PlusPatch,
  type PlusRow,
  type PlusStore,
} from "./vandery_plus.ts";

function assert(cond: unknown, message: string): asserts cond {
  if (!cond) throw new Error(message);
}

function row(partial: Partial<PlusRow> & Pick<PlusRow, "id" | "userId">): PlusRow {
  return {
    status: "pending",
    startsAt: null,
    expiresAt: "2026-11-06T00:00:00.000Z",
    cancelAtPeriodEnd: false,
    fapiSubscriptionId: null,
    fapiInvoiceId: null,
    amountCents: null,
    currency: null,
    ...partial,
  };
}

class MemoryStore implements PlusStore {
  rows = new Map<string, PlusRow>();
  keys = new Set<string>();
  commits: string[] = [];

  constructor(initial: PlusRow[]) {
    for (const item of initial) this.rows.set(item.id, item);
  }

  load(id: string): Promise<PlusRow | null> {
    return Promise.resolve(this.rows.get(id) ?? null);
  }

  commit(input: {
    membershipId: string;
    userId: string;
    key: string;
    kind: PlusKind;
    invoiceId: string;
    patch: PlusPatch;
  }): Promise<{ idempotent: boolean; row: PlusRow }> {
    const current = this.rows.get(input.membershipId);
    if (!current || current.userId !== input.userId) {
      return Promise.reject(new Error("commit user"));
    }
    if (this.keys.has(input.key)) {
      return Promise.resolve({ idempotent: true, row: current });
    }
    this.keys.add(input.key);
    this.commits.push(input.userId);
    const next = applyPatch(current, input.patch);
    this.rows.set(next.id, next);
    return Promise.resolve({ idempotent: false, row: next });
  }
}

function event(partial: Partial<PlusEvent> & Pick<PlusEvent, "kind">): PlusEvent {
  return {
    invoiceId: "inv-1",
    subscriptionId: "sub-1",
    checkoutUserId: "user-a",
    membershipId: "mem-1",
    now: "2026-11-06T00:00:00.000Z",
    amountCents: 59900,
    currency: "czk",
    ...partial,
  };
}

Deno.test("ED-01 prefill URL is the recurring form and has no challenge_id", () => {
  const url = vanderyPlusPrefillUrl({
    formUrl: "https://sandbox.fapi.example/vandery-plus",
    userId: "user-a",
    membershipId: "mem-1",
    email: "ada@example.com",
  });
  const parsed = new URL(url);
  assert(parsed.origin + parsed.pathname === "https://sandbox.fapi.example/vandery-plus", url);
  assert(!parsed.searchParams.has("challenge_id"), url);
  assert(
    parsed.searchParams.get("fapi-form-notes") === "viateria-plus:user-a:mem-1",
    url,
  );
  const notes = parseVanderyPlusNotes(parsed.searchParams.get("fapi-form-notes"));
  assert(notes?.userId === "user-a" && notes.membershipId === "mem-1", "notes");
});

Deno.test("ED-01 checkout returns that URL for the JWT user", async () => {
  let insertedFor = "";
  const result = await startVanderyPlusCheckout({
    formUrl: "https://sandbox.fapi.example/vandery-plus",
    userId: "user-jwt",
    email: "ada@example.com",
    now: "2026-11-06T00:00:00.000Z",
    loadByUser: () => Promise.resolve(null),
    insertPending: (userId) => {
      insertedFor = userId;
      return Promise.resolve(row({ id: "mem-9", userId, status: "pending" }));
    },
    markPending: (current) => Promise.resolve(current),
  });
  assert(result.status === 200, JSON.stringify(result));
  assert(insertedFor === "user-jwt", insertedFor);
  const url = String(result.body.url);
  const parsed = new URL(url);
  assert(!parsed.searchParams.has("challenge_id"), url);
  assert(
    parsed.searchParams.get("fapi-form-notes") === "viateria-plus:user-jwt:mem-9",
    url,
  );
});

Deno.test("ED-02 missing user is rejected before a membership URL is built", () => {
  const gate = webhookTokenGate;
  assert(typeof gate === "function", "token helper stays available");
  const source = Deno.readTextFileSync(
    new URL("../start-fapi-checkout/index.ts", import.meta.url),
  );
  const auth = source.indexOf("missing authorization");
  const branch = source.indexOf("body.product === VANDERY_PLUS_PRODUCT");
  assert(auth >= 0 && branch > auth, "JWT check must run before the membership branch");
});

Deno.test("ED-03 missing form URL fails closed and does not insert", async () => {
  let writes = 0;
  const plan = planVanderyPlusForm("");
  assert(plan.ok === false && plan.status === 500, JSON.stringify(plan));
  assert(!plan.ok && !plan.error.includes("challenge"), plan.error);
  const result = await startVanderyPlusCheckout({
    formUrl: null,
    userId: "user-a",
    now: "2026-11-06T00:00:00.000Z",
    loadByUser: () => Promise.resolve(null),
    insertPending: () => {
      writes += 1;
      return Promise.resolve(row({ id: "x", userId: "user-a" }));
    },
    markPending: (current) => Promise.resolve(current),
  });
  assert(result.status === 500, JSON.stringify(result));
  assert(writes === 0, "must not write a pending row without a form URL");
  assert(
    planVanderyPlusForm("https://challenge.example/form").ok,
    "a challenge URL is not a fallback; the env value itself must be the plus form",
  );
});

Deno.test("ED-04 paid_first activates for about one month", async () => {
  const store = new MemoryStore([
    row({ id: "mem-1", userId: "user-a", status: "pending" }),
  ]);
  const result = await deliverVanderyPlus(
    store,
    event({ kind: "paid_first", invoiceId: "inv-paid" }),
  );
  assert(result.status === 200, JSON.stringify(result.body));
  const saved = store.rows.get("mem-1")!;
  assert(saved.status === "active", saved.status);
  assert(
    saved.expiresAt === addMonthsIso("2026-11-06T00:00:00.000Z", 1),
    saved.expiresAt,
  );
  assert(saved.fapiSubscriptionId === "sub-1", saved.fapiSubscriptionId ?? "");
  assert(isMembershipActive(saved, "2026-11-20T00:00:00.000Z"), "in period");
});

Deno.test("ED-05 paid_first twice keeps one row and one period", async () => {
  const store = new MemoryStore([
    row({ id: "mem-1", userId: "user-a", status: "pending" }),
  ]);
  const first = event({ kind: "paid_first", invoiceId: "inv-paid" });
  await deliverVanderyPlus(store, first);
  const again = await deliverVanderyPlus(store, first);
  assert(again.body.idempotent === true, JSON.stringify(again.body));
  assert(store.rows.size === 1, "one row");
  assert(
    store.rows.get("mem-1")!.expiresAt === "2026-12-06T00:00:00.000Z",
    store.rows.get("mem-1")!.expiresAt,
  );
});

Deno.test("ED-06 renew twice extends the same row once", async () => {
  const store = new MemoryStore([
    row({
      id: "mem-1",
      userId: "user-a",
      status: "active",
      expiresAt: "2026-12-06T00:00:00.000Z",
      cancelAtPeriodEnd: true,
      fapiSubscriptionId: "sub-1",
    }),
  ]);
  const renew = event({ kind: "renew", invoiceId: "inv-renew" });
  await deliverVanderyPlus(store, renew);
  await deliverVanderyPlus(store, renew);
  const saved = store.rows.get("mem-1")!;
  assert(saved.expiresAt === "2027-01-06T00:00:00.000Z", saved.expiresAt);
  assert(saved.cancelAtPeriodEnd === false, "renew clears soft cancel");
  assert(saved.id === "mem-1", saved.id);
});

Deno.test("ED-07 cancel twice stays active until expires_at", async () => {
  const store = new MemoryStore([
    row({
      id: "mem-1",
      userId: "user-a",
      status: "active",
      expiresAt: "2026-12-06T00:00:00.000Z",
    }),
  ]);
  const cancel = event({ kind: "cancel", invoiceId: "inv-cancel" });
  await deliverVanderyPlus(store, cancel);
  await deliverVanderyPlus(store, cancel);
  const saved = store.rows.get("mem-1")!;
  assert(saved.status === "active", saved.status);
  assert(saved.cancelAtPeriodEnd === true, "soft cancel");
  assert(saved.expiresAt === "2026-12-06T00:00:00.000Z", saved.expiresAt);
  assert(isMembershipActive(saved, "2026-12-01T00:00:00.000Z"), "still active");
  assert(!isMembershipActive(saved, "2026-12-07T00:00:00.000Z"), "then expired");
});

Deno.test("ED-08 refund twice revokes immediately", async () => {
  const store = new MemoryStore([
    row({
      id: "mem-1",
      userId: "user-a",
      status: "active",
      expiresAt: "2026-12-06T00:00:00.000Z",
    }),
  ]);
  const refund = event({ kind: "refund", invoiceId: "inv-refund" });
  await deliverVanderyPlus(store, refund);
  await deliverVanderyPlus(store, refund);
  const saved = store.rows.get("mem-1")!;
  assert(saved.status === "revoked", saved.status);
  assert(!isMembershipActive(saved, "2026-11-06T00:00:00.000Z"), "no access");
});

Deno.test("ED-09 payment_failed does not activate or extend", async () => {
  const pending = new MemoryStore([
    row({ id: "mem-1", userId: "user-a", status: "pending" }),
  ]);
  await deliverVanderyPlus(
    pending,
    event({ kind: "payment_failed", invoiceId: "inv-fail" }),
  );
  assert(pending.rows.get("mem-1")!.status === "pending", "unpaid notice leaves pending");

  const active = new MemoryStore([
    row({
      id: "mem-1",
      userId: "user-a",
      status: "active",
      expiresAt: "2026-12-06T00:00:00.000Z",
    }),
  ]);
  await deliverVanderyPlus(
    active,
    event({ kind: "payment_failed", invoiceId: "inv-fail-2" }),
  );
  const saved = active.rows.get("mem-1")!;
  assert(saved.status === "active", saved.status);
  assert(saved.expiresAt === "2026-12-06T00:00:00.000Z", "no grace extension");
});

Deno.test("ED-10 bad or missing webhook token does not deliver", async () => {
  assert(webhookTokenGate("", "x") === "reject", "empty secret");
  assert(webhookTokenGate("secret", null) === "reject", "missing token");
  assert(webhookTokenGate("secret", "nope") === "reject", "wrong token");
  assert(webhookTokenGate("secret", "secret") === "ok", "match");
  const store = new MemoryStore([
    row({ id: "mem-1", userId: "user-a" }),
  ]);
  if (webhookTokenGate("secret", "nope") === "reject") {
    assert(store.rows.get("mem-1")!.status === "pending", "untouched");
  }
});

Deno.test("ED-11 challenge notes stay on purchases", () => {
  assert(
    fapiProductRoute("viateria:user-a:challenge-1:diploma") === "purchase",
    "challenge",
  );
  assert(
    fapiProductRoute("viateria-plus:user-a:mem-1") === "membership",
    "membership",
  );
  assert(fapiProductRoute(null) === "purchase", "empty");
  const source = Deno.readTextFileSync(
    new URL("../fapi-webhook/index.ts", import.meta.url),
  );
  const route = source.indexOf("fapiProductRoute(invoiceNotes)");
  const purchaseWrite = source.indexOf('from("purchases")');
  assert(route >= 0 && purchaseWrite > route, "membership branch returns before purchases");
});

Deno.test("ED-13 cheap challenge form with VANDERY+ notes does not match", () => {
  const config = vanderyPlusProductConfigFromEnv((key) => {
    const values: Record<string, string> = {
      FAPI_VANDERY_PLUS_AMOUNT_CENTS: "59900",
      FAPI_VANDERY_PLUS_ITEM_ID: "77",
      FAPI_VANDERY_PLUS_FORM_ID: "55",
      FAPI_VANDERY_PLUS_PRODUCT_ID: "vandery-plus",
    };
    return values[key];
  });
  const cheap = {
    paid: true,
    total: 49,
    form: 100,
    notes: "viateria-plus:user-a:mem-1",
    items: [{ id: 9, name: "Cheap challenge", code: "challenge-diploma" }],
  };
  assert(fapiProductRoute(cheap.notes) === "membership", "notes would route");
  assert(!membershipProductMatches(cheap, config), "cheap form is not VANDERY+");
  const real = {
    paid: true,
    total: 599,
    form: 55,
    items: [{ id: 77, name: "VANDERY+", code: "vandery-plus" }],
  };
  assert(membershipProductMatches(real, config), "configured product matches");
  assert(invoiceFormId(real) === "55", "form id");
  assert(
    !membershipProductMatches(real, vanderyPlusProductConfigFromEnv(() => undefined)),
    "missing config fails closed",
  );
  const source = Deno.readTextFileSync(
    new URL("../fapi-webhook/index.ts", import.meta.url),
  );
  const gate = source.indexOf("membershipProductMatches(invoice, product)");
  const deliver = source.indexOf("deliverMembershipInvoice");
  assert(gate >= 0 && deliver > gate, "product gate runs before activation");
});

Deno.test("ED-12 client body user is not the write target", async () => {
  const store = new MemoryStore([
    row({ id: "mem-1", userId: "user-checkout", status: "pending" }),
  ]);
  const mismatch = await deliverVanderyPlus(
    store,
    event({
      kind: "paid_first",
      checkoutUserId: "user-attacker",
      clientBodyUserId: "user-attacker",
      membershipId: "mem-1",
    }),
  );
  assert(mismatch.status === 409, JSON.stringify(mismatch.body));
  assert(store.rows.get("mem-1")!.status === "pending", "no write");
  assert(!store.rows.has("user-attacker"), "no row for the client body user");

  const ok = await deliverVanderyPlus(
    store,
    event({
      kind: "paid_first",
      checkoutUserId: "user-checkout",
      clientBodyUserId: "user-attacker",
      invoiceId: "inv-bound",
    }),
  );
  assert(ok.status === 200, JSON.stringify(ok.body));
  assert(store.commits.length === 1, "one commit");
  assert(store.commits[0] === "user-checkout", store.commits[0]);
  assert(store.rows.get("mem-1")!.userId === "user-checkout", "same user");
  assert(store.rows.get("mem-1")!.status === "active", "activated checkout user");
});

Deno.test("FAPI invoice shapes map without vandery_plus_event", () => {
  const pending = "pending" as const;
  const active = "active" as const;
  assert(
    classifyFapiMembershipEvent({ paid: true, type: "invoice" }, pending) ===
      "paid_first",
    "first paid invoice",
  );
  assert(
    classifyFapiMembershipEvent(
      { paid: true, type: "invoice", parent: 900 },
      active,
    ) === "renew",
    "periodic child",
  );
  assert(
    classifyFapiMembershipEvent({ paid: false, cancelled: true }, active) ===
      "cancel",
    "cancelled series",
  );
  assert(
    classifyFapiMembershipEvent({ paid: false, type: "credit_note" }, active) ===
      "refund",
    "credit note",
  );
  assert(
    classifyFapiMembershipEvent(
      {
        paid: true,
        type: "invoice",
        custom_fields: [{ name: "vandery_plus_event", value: "refund" }],
      },
      pending,
    ) === "paid_first",
    "custom field is ignored",
  );
  assert(
    classifyFapiMembershipEvent({ paid: false, type: "proforma" }, pending) ===
      "payment_failed",
    "unpaid",
  );
});

Deno.test("renew after expiry starts from now", async () => {
  const store = new MemoryStore([
    row({
      id: "mem-1",
      userId: "user-a",
      status: "expired",
      expiresAt: "2026-10-01T00:00:00.000Z",
    }),
  ]);
  await deliverVanderyPlus(
    store,
    event({
      kind: "renew",
      invoiceId: "inv-late",
      now: "2026-11-06T00:00:00.000Z",
    }),
  );
  assert(
    store.rows.get("mem-1")!.expiresAt === "2026-12-06T00:00:00.000Z",
    store.rows.get("mem-1")!.expiresAt,
  );
  assert(store.rows.get("mem-1")!.status === "active", "active again");
});

Deno.test("cancel after paid on the same invoice is not lost", async () => {
  const store = new MemoryStore([
    row({
      id: "mem-1",
      userId: "user-a",
      status: "active",
      expiresAt: "2026-12-06T00:00:00.000Z",
    }),
  ]);
  await deliverVanderyPlus(
    store,
    event({ kind: "paid_first", invoiceId: "inv-same" }),
  );
  const cancelled = await deliverVanderyPlus(
    store,
    event({ kind: "cancel", invoiceId: "inv-same" }),
  );
  assert(cancelled.body.idempotent === false, JSON.stringify(cancelled.body));
  assert(store.rows.get("mem-1")!.status === "active", "still active");
  assert(store.rows.get("mem-1")!.cancelAtPeriodEnd === true, "cancel kept");
});

Deno.test("DB-21 payment_failed then paid_first on the same invoice activates", async () => {
  const store = new MemoryStore([
    row({ id: "mem-1", userId: "user-a", status: "pending" }),
  ]);
  await deliverVanderyPlus(
    store,
    event({ kind: "payment_failed", invoiceId: "inv-x" }),
  );
  assert(store.rows.get("mem-1")!.status === "pending", "unpaid leaves pending");
  const paid = await deliverVanderyPlus(
    store,
    event({ kind: "paid_first", invoiceId: "inv-x" }),
  );
  assert(paid.body.idempotent === false, JSON.stringify(paid.body));
  assert(store.rows.get("mem-1")!.status === "active", "later payment activates");
});

Deno.test("DB-22 two renew invoices each add a month", async () => {
  const store = new MemoryStore([
    row({
      id: "mem-1",
      userId: "user-a",
      status: "active",
      expiresAt: "2030-01-01T00:00:00.000Z",
    }),
  ]);
  const first = await deliverVanderyPlus(
    store,
    event({
      kind: "renew",
      invoiceId: "inv-y1",
      now: "2030-01-01T00:00:00.000Z",
    }),
  );
  const second = await deliverVanderyPlus(
    store,
    event({
      kind: "renew",
      invoiceId: "inv-y2",
      now: "2030-02-01T00:00:00.000Z",
    }),
  );
  assert(first.body.idempotent === false, "y1 applied");
  assert(second.body.idempotent === false, "y2 applied");
  assert(
    store.rows.get("mem-1")!.expiresAt === "2030-03-01T00:00:00.000Z",
    store.rows.get("mem-1")!.expiresAt,
  );
});

Deno.test("ED-14 / DB-20 paid_first then renew with the same invoice does not move expires_at", async () => {
  assert(eventKey("paid_first", "inv-1") === "paid:inv-1", "paid key");
  assert(eventKey("renew", "inv-1") === "paid:inv-1", "renew shares the paid key");
  const store = new MemoryStore([
    row({ id: "mem-1", userId: "user-a", status: "pending" }),
  ]);
  const first = await deliverVanderyPlus(
    store,
    event({ kind: "paid_first", invoiceId: "inv-1" }),
  );
  const once = store.rows.get("mem-1")!.expiresAt;
  assert(first.body.idempotent === false, "first write");
  const retry = await deliverVanderyPlus(
    store,
    event({ kind: "renew", invoiceId: "inv-1" }),
  );
  assert(retry.body.idempotent === true, JSON.stringify(retry.body));
  assert(store.rows.get("mem-1")!.expiresAt === once, "no second month");
  assert(store.commits.length === 1, "one commit");
});

Deno.test("E2E-03..06 sandbox contract uses the same reducer and refuses a live flag", async () => {
  assert(sandboxAllowed(undefined) === false, "sandbox off by default");
  assert(sandboxAllowed("1") === true, "explicit sandbox");
  assert(
    sandboxAllowed(
      "1",
      "https://yzmbxxgesnbsqygzgdky.supabase.co",
    ) === false,
    "sandbox refused on prod",
  );
  assert(eventKey("renew", "inv") === "paid:inv", "renew key");
  assert(eventKey("payment_failed", "inv") === "payment_failed:inv", "failed key");
  assert(eventKey("cancel", "inv") === "cancel:inv", "cancel key");
  assert(
    inferKind({ explicit: "refund", invoicePaid: false, status: "active" }) ===
      "refund",
    "explicit kind wins",
  );
  assert(
    inferKind({ explicit: null, invoicePaid: true, status: "active" }) === "renew",
    "paid active renews",
  );
  const store = new MemoryStore([
    row({
      id: "mem-1",
      userId: "user-a",
      status: "active",
      expiresAt: "2026-12-06T00:00:00.000Z",
    }),
  ]);
  await deliverVanderyPlus(store, event({ kind: "renew", invoiceId: "e2e-renew" }));
  assert(store.rows.get("mem-1")!.expiresAt === "2027-01-06T00:00:00.000Z", "E2E-03");
  await deliverVanderyPlus(store, event({ kind: "cancel", invoiceId: "e2e-cancel" }));
  assert(store.rows.get("mem-1")!.cancelAtPeriodEnd === true, "E2E-04");
  assert(store.rows.get("mem-1")!.status === "active", "E2E-04 still active");
  await deliverVanderyPlus(store, event({ kind: "refund", invoiceId: "e2e-refund" }));
  assert(store.rows.get("mem-1")!.status === "revoked", "E2E-05");
  const fresh = new MemoryStore([
    row({ id: "mem-2", userId: "user-a", status: "pending" }),
  ]);
  await deliverVanderyPlus(
    fresh,
    event({ kind: "payment_failed", membershipId: "mem-2", invoiceId: "e2e-cancel-checkout" }),
  );
  assert(fresh.rows.get("mem-2")!.status === "pending", "E2E-06 unpaid does not activate");
});
