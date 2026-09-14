import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.10";
import {
  appendFapiPrefill,
  fapiPrefillParams,
  httpUrlOrNull,
  parseRewardVariant,
} from "../_shared/fapi.ts";

/**
 * Authenticated start of a FAPI sales-form checkout.
 *
 * Upserts `purchases` as pending with the chosen reward_variant, then returns
 * the challenge's FAPI form URL with prefilled metadata so `fapi-webhook`
 * can match the paid invoice back to this user + challenge.
 *
 * Required form custom fields (create in FAPI → Prodej → Vlastní pole):
 *   user_id, challenge_id, reward_variant
 * Optional secrets for URL prefill: FAPI_CUSTOM_FIELD_ID_USER / _CHALLENGE / _REWARD
 * Notes fallback (always set): fapi-form-notes=viateria:<user_id>:<challenge_id>:<reward_variant>
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors() });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "missing authorization" }, 401);
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
    return json({ error: "unauthorized" }, 401);
  }

  const body = await req.json();
  const challengeId = body.challenge_id as string | undefined;
  if (!challengeId) {
    return json({ error: "challenge_id required" }, 400);
  }
  const rewardVariant = parseRewardVariant(body.reward_variant);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const { data: challenge, error } = await admin
    .from("challenges")
    .select(
      "id, pricing_type, price_cents, diploma_price_cents, medal_price_cents, currency, status, fapi_form_url_diploma, fapi_form_url_medal",
    )
    .eq("id", challengeId)
    .eq("status", "published")
    .single();

  if (error || !challenge) {
    return json({ error: "challenge not available" }, 404);
  }
  if (challenge.pricing_type !== "paid") {
    return json({ error: "challenge is free" }, 400);
  }

  const isMedal = rewardVariant === "medal_and_diploma";
  const formUrl = httpUrlOrNull(
    isMedal ? challenge.fapi_form_url_medal : challenge.fapi_form_url_diploma,
  );
  if (!formUrl) {
    return json({ error: "fapi form url missing" }, 400);
  }

  const { data: existing } = await admin
    .from("purchases")
    .select("status")
    .eq("user_id", user.id)
    .eq("challenge_id", challengeId)
    .maybeSingle();
  if (existing?.status === "paid") {
    return json({ error: "already paid" }, 409);
  }

  const amountCents = isMedal
    ? (challenge.medal_price_cents ?? challenge.price_cents)
    : (challenge.diploma_price_cents ?? challenge.price_cents);

  await admin.from("purchases").upsert(
    {
      user_id: user.id,
      challenge_id: challengeId,
      status: "pending",
      amount_cents: amountCents,
      currency: challenge.currency ?? "eur",
      reward_variant: rewardVariant,
    },
    { onConflict: "user_id,challenge_id" },
  );

  const url = appendFapiPrefill(
    formUrl,
    fapiPrefillParams({
      userId: user.id,
      challengeId,
      rewardVariant,
      email: user.email,
      customFieldIdUser: Deno.env.get("FAPI_CUSTOM_FIELD_ID_USER"),
      customFieldIdChallenge: Deno.env.get("FAPI_CUSTOM_FIELD_ID_CHALLENGE"),
      customFieldIdReward: Deno.env.get("FAPI_CUSTOM_FIELD_ID_REWARD"),
    }),
  );

  return json({ url });
});

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
