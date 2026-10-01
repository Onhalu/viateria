import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.47.10";
import {
  appendFapiPrefill,
  checkoutAmountCents,
  fapiPrefillParams,
  httpUrlOrNull,
  parseRewardVariant,
  selectActiveDiscountStripe,
  type DiscountStripe,
  type PromoAssignment,
  type PromoTargetType,
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

  const promoPrices = await activeDiscountPrices(
    admin,
    user.id,
    challengeId,
  );
  const amountCents = checkoutAmountCents({
    isMedal,
    diplomaPriceCents: challenge.diploma_price_cents ?? challenge.price_cents,
    medalPriceCents: challenge.medal_price_cents ?? challenge.price_cents,
    promoDiplomaPriceCents: promoPrices?.diploma ?? null,
    promoMedalPriceCents: promoPrices?.medal ?? null,
  });

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

async function activeDiscountPrices(
  admin: SupabaseClient,
  userId: string,
  challengeId: string,
): Promise<{ diploma: number | null; medal: number | null } | null> {
  try {
    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("locale, country_code")
      .eq("id", userId)
      .maybeSingle();
    if (profileError) throw profileError;

    const { data: memberships, error: memberError } = await admin
      .from("promo_segment_members")
      .select("segment_id")
      .eq("user_id", userId);
    if (memberError) throw memberError;

    const { data: stripes, error: stripeError } = await admin
      .from("promo_stripes")
      .select(
        "id, sort_order, starts_at, ends_at, promo_diploma_price_cents, promo_medal_price_cents, promo_assignments(target_type, user_id, segment_id, locale, country_code)",
      )
      .eq("challenge_id", challengeId)
      .eq("status", "published")
      .eq("kind", "discount");
    if (stripeError) throw stripeError;

    const segmentIds = new Set<string>();
    for (const row of memberships ?? []) {
      const id = (row as { segment_id?: string }).segment_id;
      if (id) segmentIds.add(id);
    }

    const selected = selectActiveDiscountStripe(
      (stripes ?? []).map((row) =>
        discountStripeFromRow(row as Record<string, unknown>)
      ),
      {
        userId,
        locale: (profile as { locale?: string } | null)?.locale ?? null,
        countryCode:
          (profile as { country_code?: string } | null)?.country_code ?? null,
        segmentIds,
      },
      new Date(),
    );
    if (!selected) return null;
    return {
      diploma: selected.promoDiplomaPriceCents,
      medal: selected.promoMedalPriceCents,
    };
  } catch (error) {
    console.error("promo price lookup failed", error);
    return null;
  }
}

function discountStripeFromRow(row: Record<string, unknown>): DiscountStripe {
  return {
    id: String(row.id),
    sortOrder: typeof row.sort_order === "number" ? row.sort_order : 0,
    startsAt: typeof row.starts_at === "string" ? row.starts_at : null,
    endsAt: typeof row.ends_at === "string" ? row.ends_at : null,
    promoDiplomaPriceCents: centsOrNull(row.promo_diploma_price_cents),
    promoMedalPriceCents: centsOrNull(row.promo_medal_price_cents),
    assignments: assignmentsFromRaw(row.promo_assignments),
  };
}

function centsOrNull(value: unknown): number | null {
  return typeof value === "number" ? value : null;
}

function assignmentsFromRaw(raw: unknown): PromoAssignment[] {
  if (!Array.isArray(raw)) return [];
  const out: PromoAssignment[] = [];
  for (const row of raw) {
    if (!row || typeof row !== "object") continue;
    const record = row as Record<string, unknown>;
    const target = record.target_type;
    if (!isTargetType(target)) continue;
    out.push({
      targetType: target,
      userId: typeof record.user_id === "string" ? record.user_id : null,
      segmentId: typeof record.segment_id === "string"
        ? record.segment_id
        : null,
      locale: typeof record.locale === "string" ? record.locale : null,
      countryCode: typeof record.country_code === "string"
        ? record.country_code
        : null,
    });
  }
  return out;
}

function isTargetType(value: unknown): value is PromoTargetType {
  return value === "all" ||
    value === "user" ||
    value === "segment" ||
    value === "locale" ||
    value === "country";
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
