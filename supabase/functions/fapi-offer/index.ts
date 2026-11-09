import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.47.10";
import {
  callerCanReadChallenge,
  httpUrlOrNull,
  isMissingSchemaObject,
  selectSaleFormUrl,
  type SaleFormRow,
} from "../_shared/fapi.ts";
import {
  emptyOfferVariant,
  fetchOfferForFormUrl,
  type OfferVariant,
} from "../_shared/fapi_offer.ts";
import { corsHeaders, preflightResponse } from "../_shared/cors.ts";

/**
 * Authenticated price + terms for both reward variants.
 *
 * Deploy this function before the app can show live FAPI prices:
 *   supabase functions deploy fapi-offer
 *
 * There is no `sync-fapi-prices` function, and this does not call
 * `GET /item-templates?form=`. It reads the public form resource FAPI
 * embeds for the active `challenge_sale_forms` URL (legacy
 * `challenges.fapi_form_url_*` when that table is absent).
 *
 * `challenge_prices` is not a source. A missing form returns null cents
 * so the app can show its fallback instead of a CMS amount.
 *
 * No FAPI API username or key is read.
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return preflightResponse(req);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json(req, { error: "missing authorization" }, 401);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } },
  );
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();
  if (userError || !user) return json(req, { error: "unauthorized" }, 401);

  const body = await req.json().catch(() => ({}));
  const challengeId = (body as { challenge_id?: string }).challenge_id;
  if (!challengeId) return json(req, { error: "challenge_id required" }, 400);
  const locale = profileLocaleOrBody(
    (body as { locale?: string }).locale,
  );

  const { data: readable, error: readableError } = await supabase.rpc(
    "challenge_readable",
    { p_challenge_id: challengeId },
  );
  if (!callerCanReadChallenge(readable, readableError)) {
    return json(req, { error: "challenge not available" }, 404);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
  const { data: challenge, error } = await admin
    .from("challenges")
    .select("id, status, fapi_form_url_diploma, fapi_form_url_medal")
    .eq("id", challengeId)
    .eq("status", "published")
    .maybeSingle();
  if (error || !challenge) {
    return json(req, { error: "challenge not available" }, 404);
  }

  const diplomaUrl = await activeSaleFormUrl(
    admin,
    challengeId,
    "diploma",
    locale,
  ) ?? httpUrlOrNull(challenge.fapi_form_url_diploma);
  const medalUrl = await activeSaleFormUrl(
    admin,
    challengeId,
    "medal_and_diploma",
    locale,
  ) ?? httpUrlOrNull(challenge.fapi_form_url_medal);

  const [diploma, medal] = await Promise.all([
    offerForUrl(diplomaUrl),
    offerForUrl(medalUrl),
  ]);
  return json(req, { diploma, medal });
});

function profileLocaleOrBody(raw: unknown): string {
  if (raw === "cs" || raw === "en" || raw === "de") return raw;
  return "cs";
}

async function offerForUrl(formUrl: string | null): Promise<OfferVariant> {
  if (!formUrl) return emptyOfferVariant();
  try {
    return await fetchOfferForFormUrl(formUrl) ?? emptyOfferVariant();
  } catch (error) {
    console.error("fapi-offer form read failed", error);
    return emptyOfferVariant();
  }
}

async function activeSaleFormUrl(
  admin: SupabaseClient,
  challengeId: string,
  rewardVariant: string,
  locale: string,
): Promise<string | null> {
  const { data, error } = await admin
    .from("challenge_sale_forms")
    .select(
      "locale, reward_variant, fapi_form_url, status, valid_from, valid_to",
    )
    .eq("challenge_id", challengeId)
    .eq("reward_variant", rewardVariant)
    .eq("status", "published");
  if (error) {
    if (isMissingSchemaObject(error)) return null;
    console.error("sale form lookup failed", error.message);
    return null;
  }
  return selectSaleFormUrl(
    (data ?? []) as SaleFormRow[],
    rewardVariant,
    locale,
  );
}

function json(req: Request, body: unknown, status = 200) {
  const headers = corsHeaders(req);
  headers.set("Content-Type", "application/json");
  return new Response(JSON.stringify(body), { status, headers });
}
