import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.10";
import {
  FAPI_API_BASE,
  fetchFapiInvoice,
  isInvoiceSecurityValid,
  parseNotification,
  parseRewardVariant,
  purchaseKeysFromInvoice,
  webhookTokenFromRequest,
} from "../_shared/fapi.ts";

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

  const webhookSecret = Deno.env.get("FAPI_WEBHOOK_SECURITY") ?? "";
  if (webhookSecret) {
    const token = webhookTokenFromRequest(req);
    if (token !== webhookSecret) {
      return json({ status: "FAILED", message: "invalid webhook token" }, 401);
    }
  }

  const payload = await req.text();
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

  const { data: existing } = await admin
    .from("purchases")
    .select("status, reward_variant, amount_cents, currency")
    .eq("user_id", keys.userId)
    .eq("challenge_id", keys.challengeId)
    .maybeSingle();

  if (existing?.status === "paid") {
    return json({ status: "OK", message: "already paid" });
  }

  const rewardVariant = keys.rewardVariant ??
    (existing?.reward_variant
      ? parseRewardVariant(existing.reward_variant)
      : "diploma");

  await admin.from("purchases").upsert(
    {
      user_id: keys.userId,
      challenge_id: keys.challengeId,
      status: "paid",
      paid_at: new Date().toISOString(),
      reward_variant: rewardVariant,
      amount_cents: existing?.amount_cents ?? 0,
      currency: existing?.currency ??
        (typeof invoice.currency === "string" ? invoice.currency : "eur"),
    },
    { onConflict: "user_id,challenge_id" },
  );

  return json({ status: "OK" });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
