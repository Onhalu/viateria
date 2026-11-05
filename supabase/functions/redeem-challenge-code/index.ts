import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.10";
import { hashCode, isUuid, normalizeCode, redeemHttpStatus } from "./code.ts";

/**
 * Redeem a single-use vyšlápni.cz code for the signed-in user.
 *
 * JWT required. The plaintext code is normalized and hashed here and is not
 * logged. Writes go through service_role + redeem_challenge_code only.
 * Flutter must not embed the service role key.
 *
 * Success: purchases.status = paid, reward_variant = medal_and_diploma,
 * amount_cents = 0, currency from the challenge. An existing paid row returns
 * already_unlocked and does not consume the code (OQ-R5).
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors() });
  }
  if (req.method !== "POST") {
    return json({ ok: false, error: "invalid_code" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.toLowerCase().startsWith("bearer ")) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } },
  );
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();
  if (userError || !user) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }

  let body: Record<string, unknown> = {};
  try {
    const parsed = await req.json();
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      body = parsed as Record<string, unknown>;
    }
  } catch {
    body = {};
  }

  const challengeRaw = body.challenge_id;
  const normalized = normalizeCode(body.code);
  const formatOk = normalized != null && isUuid(challengeRaw);
  const challengeId = isUuid(challengeRaw)
    ? challengeRaw
    : "00000000-0000-0000-0000-000000000000";
  const codeHash = normalized ? await hashCode(normalized) : "";

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!serviceKey) {
    console.error("redeem-challenge-code missing service role key");
    return json({ ok: false, error: "invalid_code" }, 500);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    serviceKey,
  );
  const { data, error } = await admin.rpc("redeem_challenge_code", {
    p_user_id: user.id,
    p_email: user.email ?? "",
    p_challenge_id: challengeId,
    p_code_hash: codeHash,
    p_format_ok: formatOk,
  });
  if (error) {
    console.error("redeem-challenge-code rpc failed", error.code);
    return json({ ok: false, error: "invalid_code" }, 500);
  }

  const payload = asRecord(data);
  if (payload.ok === true) {
    return json({
      ok: true,
      challenge_id: typeof payload.challenge_id === "string"
        ? payload.challenge_id
        : challengeId,
      already_unlocked: payload.already_unlocked === true,
    });
  }

  const errorCode = typeof payload.error === "string"
    ? payload.error
    : "invalid_code";
  return json({ ok: false, error: errorCode }, redeemHttpStatus(errorCode));
});

function asRecord(value: unknown): Record<string, unknown> {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function cors() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors(), "Content-Type": "application/json" },
  });
}
