import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.47.10";
import {
  decideDiploma,
  diplomaObjectPath,
  entitledFromRows,
  hashForRow,
  isCacheHit,
  type IssuedDiplomaRow,
  type PriceSnapshot,
} from "./access.ts";
import { RENDERER_VERSION } from "./hash.ts";
import { ITALIC_FONT_ASSET, LOGO_ASSET, readBundledAsset, renderDiploma } from "./render.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors() });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "missing authorization" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return json({ error: "unauthorized" }, 401);

  let body: { challenge_id?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const challengeId = body.challenge_id ?? "";
  if (!UUID_RE.test(challengeId)) return json({ error: "challenge_id required" }, 400);

  const admin = createClient(supabaseUrl, serviceKey);
  const loaded = await admin
    .from("challenge_diplomas")
    .select(
      "id, user_id, challenge_id, revoked_at, lang, headline, body, challenge_title, recipient_name_display, completed_at, background_variant, image_path, render_hash",
    )
    .eq("user_id", userData.user.id)
    .eq("challenge_id", challengeId)
    .maybeSingle();
  if (loaded.error) return json({ error: "diploma_lookup_failed" }, 500);

  const row = (loaded.data as IssuedDiplomaRow | null) ?? null;
  const entitled = row
    ? await loadEntitled(admin, userData.user.id, challengeId)
    : false;
  const decision = decideDiploma(row, entitled);
  if (!decision.ok || !row) {
    return json(
      { error: decision.ok ? "not_found" : decision.error },
      decision.ok ? 404 : decision.status,
    );
  }

  const hash = await hashForRow(row);
  const objectPath = diplomaObjectPath(row.user_id, row.challenge_id, hash);
  if (isCacheHit(row, hash, objectPath)) {
    const url = await signedUrl(admin, objectPath);
    if (!url) return json({ error: "sign_failed" }, 500);
    return json({ url, cached: true, render_hash: hash }, 200);
  }

  let png: Uint8Array;
  try {
    const assets = await loadRenderAssets(admin, row.background_variant ?? 1);
    png = await renderDiploma(row, assets);
  } catch (error) {
    console.error("diploma render failed", error);
    return json({ error: "render_failed" }, 500);
  }

  const upload = await admin.storage.from("diplomas").upload(objectPath, png, {
    contentType: "image/png",
    upsert: true,
  });
  if (upload.error) return json({ error: "upload_failed" }, 500);

  const recorded = await admin.rpc("record_diploma_render", {
    p_diploma_id: row.id,
    p_render_hash: hash,
    p_image_path: objectPath,
    p_renderer_version: RENDERER_VERSION,
  });
  if (recorded.error) {
    await admin.storage.from("diplomas").remove([objectPath]);
    const message = recorded.error.message ?? "";
    if (message.includes("not_entitled")) {
      return json({ error: "not_entitled" }, 402);
    }
    return json({ error: "record_failed" }, 500);
  }

  const previous = (recorded.data as { previous_image_path?: string | null } | null)
    ?.previous_image_path;
  if (previous && previous !== objectPath) {
    await admin.storage.from("diplomas").remove([previous]);
  }

  const url = await signedUrl(admin, objectPath);
  if (!url) return json({ error: "sign_failed" }, 500);
  return json({ url, cached: false, render_hash: hash }, 200);
});

async function loadEntitled(
  admin: SupabaseClient,
  userId: string,
  challengeId: string,
): Promise<boolean> {
  const participation = await admin
    .from("challenge_participations")
    .select("status")
    .eq("user_id", userId)
    .eq("challenge_id", challengeId)
    .eq("status", "completed")
    .maybeSingle();
  if (participation.error || !participation.data) return false;

  const purchase = await admin
    .from("purchases")
    .select("id")
    .eq("user_id", userId)
    .eq("challenge_id", challengeId)
    .eq("status", "paid")
    .limit(1);
  const paid = !purchase.error && (purchase.data?.length ?? 0) > 0;

  const prices = await admin
    .from("challenge_prices")
    .select("diploma_price_cents, status, valid_from, valid_to")
    .eq("challenge_id", challengeId)
    .eq("status", "published");
  const challenge = await admin
    .from("challenges")
    .select("pricing_type")
    .eq("id", challengeId)
    .maybeSingle();
  if (prices.error || challenge.error) return paid;

  const snapshots: PriceSnapshot[] = (prices.data ?? []).map((row) => ({
    diplomaPriceCents: Number(row.diploma_price_cents ?? 0),
    status: String(row.status ?? ""),
    validFrom: String(row.valid_from),
    validTo: row.valid_to == null ? null : String(row.valid_to),
  }));
  return entitledFromRows({
    completed: true,
    paid,
    prices: snapshots,
    pricingType: (challenge.data?.pricing_type as string | null) ?? null,
    now: new Date(),
  });
}

async function loadRenderAssets(admin: SupabaseClient, variant: number) {
  const background = await assetOrBundle(
    admin,
    `bg/${variant}.png`,
    `bg/${variant}.png`,
  );
  const logo = await assetOrBundle(admin, LOGO_ASSET, LOGO_ASSET);
  const font = await assetOrBundle(
    admin,
    "fonts/PlayfairDisplay.ttf",
    "fonts/PlayfairDisplay.ttf",
  );
  let fontItalic: Uint8Array | null = null;
  try {
    fontItalic = await assetOrBundle(admin, ITALIC_FONT_ASSET, ITALIC_FONT_ASSET);
  } catch {
    fontItalic = null; // layout B then renders its italic lines in Regular
  }
  return { background, logo, font, fontItalic };
}

async function assetOrBundle(
  admin: SupabaseClient,
  objectPath: string,
  bundled: string,
): Promise<Uint8Array> {
  const downloaded = await admin.storage.from("diploma-assets").download(objectPath);
  if (!downloaded.error && downloaded.data) {
    return new Uint8Array(await downloaded.data.arrayBuffer());
  }
  return await readBundledAsset(bundled);
}

async function signedUrl(admin: SupabaseClient, objectPath: string): Promise<string | null> {
  const signed = await admin.storage.from("diplomas").createSignedUrl(objectPath, 60 * 60);
  return signed.data?.signedUrl ?? null;
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
