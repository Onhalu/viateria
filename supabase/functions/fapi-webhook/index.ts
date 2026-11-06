import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.47.10";
import {
  FAPI_API_BASE,
  fapiClientId,
  fapiInvoiceId,
  fetchFapiInvoice,
  invoiceCurrencyCode,
  invoiceTotalCents,
  isInvoiceSecurityValid,
  isMissingSchemaObject,
  isWebhookTokenValid,
  parseNotification,
  parseRewardVariant,
  purchaseKeysFromInvoice,
  purchaseUnlockPlan,
  webhookTokenFromRequest,
  type FapiInvoice,
} from "../_shared/fapi.ts";
import {
  deliverVanderyPlus,
  fapiProductRoute,
  inferKind,
  invoiceCustomField,
  parseSandboxEvent,
  parseVanderyPlusNotes,
  plusRowFromDb,
  sandboxAllowed,
  type PlusRow,
  type PlusStore,
} from "../_shared/vandery_plus.ts";

/**
 * FAPI paid-invoice notification.
 *
 * FAPI POSTs application/x-www-form-urlencoded:
 *   id|invoice, time (unix), security (hash)
 *
 * Verify `security` with the official invoice hash after GET /invoices/{id}
 * (Basic auth: FAPI_API_USERNAME + FAPI_API_KEY). Respond 2xx quickly.
 *
 * See ./README.md for secrets, custom fields, and notification URL setup.
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return json({ status: "OK" });
  }
  if (req.method !== "POST") {
    return json({ status: "FAILED", message: "POST required" }, 405);
  }

  // Fail closed. An unset secret used to skip this check and still mark
  // purchases paid. Missing and wrong tokens share one response so the
  // body does not reveal whether the secret is configured.
  const webhookSecret = Deno.env.get("FAPI_WEBHOOK_SECURITY") ?? "";
  const token = webhookTokenFromRequest(req);
  if (!isWebhookTokenValid(webhookSecret, token)) {
    if (webhookSecret.length === 0) {
      console.error("fapi-webhook rejected: FAPI_WEBHOOK_SECURITY is not set");
    }
    return json({ status: "FAILED", message: "invalid webhook token" }, 401);
  }

  const payload = await req.text();

  // Sandbox contract only. Live FAPI is never called for this body.
  // Missing FAPI_MEMBERSHIP_SANDBOX=1 fails closed and writes nothing.
  const sandboxEvent = parseSandboxEvent(payload);
  if (sandboxEvent) {
    if (!sandboxAllowed(Deno.env.get("FAPI_MEMBERSHIP_SANDBOX"))) {
      return json({ status: "FAILED", message: "sandbox disabled" }, 401);
    }
    const admin = serviceClient();
    const result = await deliverVanderyPlus(
      supabasePlusStore(admin),
      sandboxEvent,
    );
    return json(result.body, result.status);
  }

  const notice = parseNotification(payload, req.headers.get("content-type"));
  if (!notice.invoiceId || !notice.time || !notice.security) {
    return json({ status: "FAILED", message: "id, time, security required" }, 400);
  }

  const username = Deno.env.get("FAPI_API_USERNAME") ?? "";
  const apiKey = Deno.env.get("FAPI_API_KEY") ??
    Deno.env.get("FAPI_API_TOKEN") ??
    "";
  if (!username || !apiKey) {
    return json({ status: "FAILED", message: "fapi credentials missing" }, 500);
  }

  let invoice;
  try {
    invoice = await fetchFapiInvoice(
      notice.invoiceId,
      username,
      apiKey,
      Deno.env.get("FAPI_API_BASE") ?? FAPI_API_BASE,
    );
  } catch (_error) {
    return json({ status: "FAILED", message: "invoice lookup failed" }, 400);
  }

  if (!await isInvoiceSecurityValid(invoice, notice.time, notice.security)) {
    return json({ status: "FAILED", message: "Invalid security" }, 400);
  }

  const invoiceNotes = firstInvoiceNotes(invoice);
  if (fapiProductRoute(invoiceNotes) === "membership") {
    const admin = serviceClient();
    const result = await deliverMembershipInvoice(admin, invoice, invoiceNotes);
    return json(result.body, result.status);
  }

  if (!invoice.paid) {
    return json({
      status: "SKIPPED",
      message: "Invoice is not paid",
    });
  }

  const keys = purchaseKeysFromInvoice(invoice);
  if (!keys.userId || !keys.challengeId) {
    return json({
      status: "SKIPPED",
      message: "missing user_id or challenge_id custom fields",
    });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const invoiceId = fapiInvoiceId(invoice);
  const amountCents = invoiceTotalCents(invoice);
  const currency = invoiceCurrencyCode(invoice);
  if (!invoiceId || amountCents == null || !currency) {
    return json({
      status: "FAILED",
      message: "invoice id, total, or currency missing",
    }, 500);
  }
  const clientId = fapiClientId(invoice);

  // Replay of this invoice is a no-op. UNIQUE(fapi_invoice_id) is the
  // backstop if two deliveries pass this lookup together.
  const { data: applied, error: appliedError } = await admin
    .from("purchases")
    .select("id")
    .eq("fapi_invoice_id", invoiceId)
    .maybeSingle();
  if (appliedError) {
    console.error("fapi-webhook invoice lookup failed", appliedError.message);
    return json({ status: "FAILED", message: "purchase lookup failed" }, 500);
  }
    if (applied) {
    const profileError = await linkProfileFapiClient(
      admin,
      keys.userId,
      clientId,
    );
    if (profileError) return profileError;
    const joinedError = await stampParticipationJoined(
      admin,
      keys.userId,
      keys.challengeId,
      new Date().toISOString(),
    );
    if (joinedError) return joinedError;
    return json({ status: "OK", message: "already applied" });
  }

  const { data: existing, error: existingError } = await admin
    .from("purchases")
    .select("status, reward_variant")
    .eq("user_id", keys.userId)
    .eq("challenge_id", keys.challengeId)
    .maybeSingle();
  if (existingError) {
    console.error("fapi-webhook purchase lookup failed", existingError.message);
    return json({ status: "FAILED", message: "purchase lookup failed" }, 500);
  }

  // Happy path: start-fapi-checkout inserted pending, then this invoice
  // marks that row paid. Replay of the same invoice id is handled above.
  // Do not insert a paid row for a user/challenge that never started checkout.
  const plan = purchaseUnlockPlan(existing);
  if (plan === "already_paid") {
    const joinedError = await stampParticipationJoined(
      admin,
      keys.userId,
      keys.challengeId,
      new Date().toISOString(),
    );
    if (joinedError) return joinedError;
    return json({ status: "OK", message: "already paid" });
  }
  if (plan !== "mark_paid") {
    return json({ status: "FAILED", message: "no pending purchase" }, 409);
  }

  const paidAt = new Date().toISOString();
  const rewardVariant = keys.rewardVariant ??
    (existing?.reward_variant
      ? parseRewardVariant(existing.reward_variant)
      : "diploma");

  const { data: updated, error: updateError } = await admin
    .from("purchases")
    .update({
      status: "paid",
      paid_at: paidAt,
      reward_variant: rewardVariant,
      amount_cents: amountCents,
      currency,
      fapi_invoice_id: invoiceId,
      ...(clientId ? { fapi_client_id: clientId } : {}),
    })
    .eq("user_id", keys.userId)
    .eq("challenge_id", keys.challengeId)
    .eq("status", "pending")
    .select("id");

  if (updateError) {
    if (isUniqueViolation(updateError)) {
      const profileError = await linkProfileFapiClient(
        admin,
        keys.userId,
        clientId,
      );
      if (profileError) return profileError;
      const joinedError = await stampParticipationJoined(
        admin,
        keys.userId,
        keys.challengeId,
        paidAt,
      );
      if (joinedError) return joinedError;
      return json({ status: "OK", message: "already applied" });
    }
    console.error("fapi-webhook purchase update failed", updateError.message);
    return json({ status: "FAILED", message: "purchase update failed" }, 500);
  }
  if (!updated || updated.length === 0) {
    const { data: again, error: againError } = await admin
      .from("purchases")
      .select("status, fapi_invoice_id")
      .eq("user_id", keys.userId)
      .eq("challenge_id", keys.challengeId)
      .maybeSingle();
    if (againError) {
      console.error("fapi-webhook purchase recheck failed", againError.message);
      return json({ status: "FAILED", message: "purchase lookup failed" }, 500);
    }
    if (again?.fapi_invoice_id === invoiceId || again?.status === "paid") {
      const joinedError = await stampParticipationJoined(
        admin,
        keys.userId,
        keys.challengeId,
        paidAt,
      );
      if (joinedError) return joinedError;
      return json({ status: "OK", message: "already applied" });
    }
    return json({ status: "FAILED", message: "no pending purchase" }, 409);
  }

  const profileError = await linkProfileFapiClient(admin, keys.userId, clientId);
  if (profileError) return profileError;
  const joinedError = await stampParticipationJoined(
    admin,
    keys.userId,
    keys.challengeId,
    paidAt,
  );
  if (joinedError) return joinedError;

  return json({ status: "OK" });
});

/**
 * Sets `challenge_participations.joined_at` from the paid invoice.
 * Inserts `joined` only when the user has no row yet. Does not rewind
 * `in_progress` / `completed`. Missing table (pre-0024) is ignored.
 */
async function stampParticipationJoined(
  admin: SupabaseClient,
  userId: string,
  challengeId: string,
  joinedAt: string,
): Promise<Response | null> {
  const { data: existing, error: readError } = await admin
    .from("challenge_participations")
    .select("id, joined_at")
    .eq("user_id", userId)
    .eq("challenge_id", challengeId)
    .maybeSingle();
  if (readError) {
    if (isMissingSchemaObject(readError)) {
      console.error(
        "challenge_participations not available yet",
        readError.message,
      );
      return null;
    }
    console.error(
      "fapi-webhook participation lookup failed",
      readError.message,
    );
    return json({ status: "FAILED", message: "participation lookup failed" }, 500);
  }
  if (!existing) {
    const { error: insertError } = await admin
      .from("challenge_participations")
      .insert({
        user_id: userId,
        challenge_id: challengeId,
        status: "joined",
        joined_at: joinedAt,
      });
    if (!insertError) return null;
    if (isUniqueViolation(insertError) || isMissingSchemaObject(insertError)) {
      return null;
    }
    console.error(
      "fapi-webhook participation insert failed",
      insertError.message,
    );
    return json({ status: "FAILED", message: "participation insert failed" }, 500);
  }
  if (existing.joined_at) return null;
  const { error: updateError } = await admin
    .from("challenge_participations")
    .update({ joined_at: joinedAt })
    .eq("id", existing.id);
  if (!updateError) return null;
  console.error(
    "fapi-webhook participation update failed",
    updateError.message,
  );
  return json({ status: "FAILED", message: "participation update failed" }, 500);
}

function isUniqueViolation(error: { code?: string; message?: string }): boolean {
  return error.code === "23505" ||
    (error.message ?? "").toLowerCase().includes("duplicate key");
}

/** Sets profiles.fapi_client_id only when it is still empty. */
async function linkProfileFapiClient(
  admin: SupabaseClient,
  userId: string,
  clientId: string | null,
): Promise<Response | null> {
  if (!clientId) return null;
  const { error } = await admin
    .from("profiles")
    .update({ fapi_client_id: clientId })
    .eq("id", userId)
    .is("fapi_client_id", null);
  if (!error) return null;
  if (isUniqueViolation(error)) {
    console.error(
      "fapi-webhook profile client id already linked elsewhere",
      error.message,
    );
    return null;
  }
  console.error("fapi-webhook profile update failed", error.message);
  return json({ status: "FAILED", message: "profile update failed" }, 500);
}

function serviceClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
}

function firstInvoiceNotes(invoice: FapiInvoice): string | null {
  for (const value of [invoice.notes, invoice.clients_note, invoice.client_note]) {
    if (typeof value === "string" && value.trim()) return value;
  }
  return null;
}

function supabasePlusStore(admin: SupabaseClient): PlusStore {
  return {
    async load(id: string): Promise<PlusRow | null> {
      const { data, error } = await admin
        .from("vandery_plus_memberships")
        .select(
          "id, user_id, status, starts_at, expires_at, cancel_at_period_end, fapi_subscription_id, fapi_invoice_id, amount_cents, currency",
        )
        .eq("id", id)
        .maybeSingle();
      if (error || !data) return null;
      return plusRowFromDb(data as Record<string, unknown>);
    },
    async commit(input) {
      const { data, error } = await admin.rpc("commit_vandery_plus_event", {
        p_membership_id: input.membershipId,
        p_user_id: input.userId,
        p_idempotency_key: input.key,
        p_kind: input.kind,
        p_invoice_id: input.invoiceId,
        p_patch: input.patch,
      });
      if (error) throw new Error(error.message);
      const payload = (data ?? {}) as {
        status?: string;
        reason?: string;
        idempotent?: boolean;
      };
      if (payload.status === "rejected") {
        throw new Error(payload.reason ?? "rejected");
      }
      const row = await this.load(input.membershipId);
      if (!row) throw new Error("membership missing after commit");
      return { idempotent: payload.idempotent === true, row };
    },
  };
}

async function deliverMembershipInvoice(
  admin: SupabaseClient,
  invoice: FapiInvoice,
  notes: string | null,
) {
  const parsed = parseVanderyPlusNotes(notes);
  if (!parsed) {
    return {
      status: 400,
      body: { status: "FAILED", message: "membership notes invalid" },
      wrote: false,
      row: null,
    };
  }
  const store = supabasePlusStore(admin);
  try {
    const loaded = await store.load(parsed.membershipId);
    if (!loaded) {
      return {
        status: 409,
        body: { status: "FAILED", message: "no checkout session" },
        wrote: false,
        row: null,
      };
    }
    const kind = inferKind({
      explicit: invoiceCustomField(invoice.custom_fields, "vandery_plus_event"),
      invoicePaid: Boolean(invoice.paid),
      status: loaded.status,
    });
    if (!kind) {
      return {
        status: 200,
        body: { status: "SKIPPED", message: "membership event not applicable" },
        wrote: false,
        row: loaded,
      };
    }
    const invoiceId = fapiInvoiceId(invoice);
    if (!invoiceId) {
      return {
        status: 500,
        body: { status: "FAILED", message: "invoice id missing" },
        wrote: false,
        row: loaded,
      };
    }
    return await deliverVanderyPlus(store, {
      kind,
      invoiceId,
      subscriptionId: invoiceCustomField(
        invoice.custom_fields,
        "fapi_subscription_id",
      ),
      checkoutUserId: parsed.userId,
      membershipId: parsed.membershipId,
      amountCents: invoiceTotalCents(invoice),
      currency: invoiceCurrencyCode(invoice),
      now: new Date().toISOString(),
    });
  } catch (error) {
    console.error("fapi-webhook membership commit failed", error);
    return {
      status: 500,
      body: { status: "FAILED", message: "membership commit failed" },
      wrote: false,
      row: null,
    };
  }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
