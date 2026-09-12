import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import Stripe from "https://esm.sh/stripe@16.12.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.10";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2024-06-20",
  httpClient: Stripe.createFetchHttpClient(),
});

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
  const rewardVariant =
    body.reward_variant === "medal_and_diploma" ||
    body.reward_variant === "medalAndDiploma"
      ? "medal_and_diploma"
      : "diploma";

  const admin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const { data: challenge, error } = await admin
    .from("challenges")
    .select(
      "id, pricing_type, price_cents, diploma_price_cents, medal_price_cents, currency, status, stripe_price_id, stripe_price_id_diploma, stripe_price_id_medal, challenge_i18n(locale, title)",
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

  const origin = req.headers.get("origin") ?? "https://viateria.app";
  const title =
    challenge.challenge_i18n?.find((row: { locale: string }) => row.locale === "en")
      ?.title ?? "Viateria challenge";

  const isMedal = rewardVariant === "medal_and_diploma";
  const stripePriceId = isMedal
    ? (challenge.stripe_price_id_medal ?? challenge.stripe_price_id)
    : (challenge.stripe_price_id_diploma ?? challenge.stripe_price_id);
  const amountCents = isMedal
    ? (challenge.medal_price_cents ?? challenge.price_cents)
    : (challenge.diploma_price_cents ?? challenge.price_cents);

  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    success_url: `${origin}/challenge/${challengeId}?checkout=success`,
    cancel_url: `${origin}/challenge/${challengeId}?checkout=cancel`,
    line_items: stripePriceId
      ? [{ price: stripePriceId, quantity: 1 }]
      : [
          {
            quantity: 1,
            price_data: {
              currency: challenge.currency ?? "eur",
              unit_amount: amountCents,
              product_data: { name: title },
            },
          },
        ],
    metadata: {
      user_id: user.id,
      challenge_id: challengeId,
      reward_variant: rewardVariant,
    },
    client_reference_id: `${user.id}:${challengeId}`,
  });

  await admin.from("purchases").upsert(
    {
      user_id: user.id,
      challenge_id: challengeId,
      stripe_checkout_session_id: session.id,
      status: "pending",
      amount_cents: amountCents,
      currency: challenge.currency ?? "eur",
      reward_variant: rewardVariant,
    },
    { onConflict: "user_id,challenge_id" },
  );

  return json({ url: session.url });
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
