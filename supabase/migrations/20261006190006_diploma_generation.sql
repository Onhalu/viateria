-- =============================================================================
-- 0026_diploma_generation.sql   (SPEC-diploma-generation §9 – DB delta, SCHVÁLENO 2026-10-07)
-- READY FOR REPO – NOT APPLIED on prod (await Ondřej apply OK)  |  Viateria yzmbxxgesnbsqygzgdky
-- Revised 2026-10-07: drop set_diploma_name/name_edits; PNG+alpha paths; period_* audit-only.
-- Builds ON redesign 0024 challenge_diplomas (templates user_id IS NULL / issued with
-- template_id, partial UNIQUE (challenge_id, user_id)). No parallel table.
-- DEPENDS ON: 0021 (pick_locale, challenge_titles, challenge_prices),
--             0024 (challenge_participations, challenge_diplomas, issue fn),
--             0025 (verify_waypoint → private.issue_challenge_diploma on completion;
--                   promo gate from PR #36 0018).
-- Chain: 0018 → 0021–0025 → THIS 0026 → 0027 W4 HOLD.
-- Adds:
--   * issued-row render columns (recipient_name_display, background_variant 1–4,
--     image_path, render_hash, rendered_at, renderer_version)
--   * period_from/period_to/period_days – AUDIT ONLY (UI shows "dokončeno dne …" from completed_at)
--   * private.cs_accusative() – port of sklonovani() (first-name accusative)
--   * private.issue_challenge_diploma – re-defined: + display name, background, period audit
--   * private.diploma_entitled()
--   * public.diploma_status()
--   * public.record_diploma_render() – Edge service_role only; paths end in .png
--   * buckets diplomas (image/png, owner read) + diploma-assets (service_role)
-- New functions: SET search_path = '' + fully-qualified names.
-- =============================================================================

DO $$
BEGIN
  IF to_regclass('public.challenge_diplomas') IS NULL
     OR to_regclass('public.challenge_participations') IS NULL
     OR to_regclass('public.challenge_prices') IS NULL THEN
    RAISE EXCEPTION '0026: requires redesign 0021–0024 (challenge_prices, challenge_participations, challenge_diplomas)';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1) Render columns on challenge_diplomas (issued rows)
-- ---------------------------------------------------------------------------
ALTER TABLE public.challenge_diplomas
  ADD COLUMN IF NOT EXISTS recipient_name_display text,
  ADD COLUMN IF NOT EXISTS background_variant smallint,
  ADD COLUMN IF NOT EXISTS image_path text,
  ADD COLUMN IF NOT EXISTS render_hash text,
  ADD COLUMN IF NOT EXISTS rendered_at timestamptz,
  ADD COLUMN IF NOT EXISTS renderer_version integer,
  ADD COLUMN IF NOT EXISTS period_from date,
  ADD COLUMN IF NOT EXISTS period_to date;

-- Drop product columns removed by SCHVÁLENO SPEC (may exist from earlier draft)
DROP FUNCTION IF EXISTS public.set_diploma_name(uuid, text);
ALTER TABLE public.challenge_diplomas DROP CONSTRAINT IF EXISTS challenge_diplomas_name_edits_check;
ALTER TABLE public.challenge_diplomas DROP COLUMN IF EXISTS name_edits;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'public' AND table_name = 'challenge_diplomas'
                   AND column_name = 'period_days') THEN
    ALTER TABLE public.challenge_diplomas
      ADD COLUMN period_days integer GENERATED ALWAYS AS (period_to - period_from + 1) STORED;
  END IF;
END $$;

ALTER TABLE public.challenge_diplomas DROP CONSTRAINT IF EXISTS challenge_diplomas_background_variant_check;
ALTER TABLE public.challenge_diplomas ADD CONSTRAINT challenge_diplomas_background_variant_check
  CHECK (background_variant IS NULL OR background_variant BETWEEN 1 AND 4);
ALTER TABLE public.challenge_diplomas DROP CONSTRAINT IF EXISTS challenge_diplomas_display_name_check;
ALTER TABLE public.challenge_diplomas ADD CONSTRAINT challenge_diplomas_display_name_check
  CHECK (recipient_name_display IS NULL
         OR (char_length(recipient_name_display) BETWEEN 1 AND 80
             AND recipient_name_display !~ '[[:cntrl:]]'));
ALTER TABLE public.challenge_diplomas DROP CONSTRAINT IF EXISTS challenge_diplomas_period_check;
ALTER TABLE public.challenge_diplomas ADD CONSTRAINT challenge_diplomas_period_check
  CHECK (period_from IS NULL OR period_to IS NULL OR period_to >= period_from);
ALTER TABLE public.challenge_diplomas DROP CONSTRAINT IF EXISTS challenge_diplomas_render_coherent;
ALTER TABLE public.challenge_diplomas ADD CONSTRAINT challenge_diplomas_render_coherent
  CHECK ((image_path IS NULL) = (render_hash IS NULL)
     AND (image_path IS NULL) = (rendered_at IS NULL)
     AND (image_path IS NULL) = (renderer_version IS NULL));
ALTER TABLE public.challenge_diplomas DROP CONSTRAINT IF EXISTS challenge_diplomas_render_issued_only;
ALTER TABLE public.challenge_diplomas ADD CONSTRAINT challenge_diplomas_render_issued_only
  CHECK (user_id IS NOT NULL
         OR (recipient_name_display IS NULL AND background_variant IS NULL AND image_path IS NULL
             AND period_from IS NULL AND period_to IS NULL));
ALTER TABLE public.challenge_diplomas DROP CONSTRAINT IF EXISTS challenge_diplomas_issued_background;
ALTER TABLE public.challenge_diplomas ADD CONSTRAINT challenge_diplomas_issued_background
  CHECK (user_id IS NULL OR background_variant IS NOT NULL) NOT VALID;

COMMENT ON COLUMN public.challenge_diplomas.recipient_name IS
  'Issued: snapshot of profiles.display_name (nominative) at issue time. No user edit after issue (SPEC SCHVÁLENO 2026-10-07).';
COMMENT ON COLUMN public.challenge_diplomas.recipient_name_display IS
  'Issued: printed name after "pro". cs = ACCUSATIVE of first name (private.cs_accusative); en/de later = as entered. NULL = missing name → do not render. NOT user-editable.';
COMMENT ON COLUMN public.challenge_diplomas.background_variant IS
  'Issued: background bg/{1..4} in bucket diploma-assets, drawn ONCE at issue (re-render keeps it).';
COMMENT ON COLUMN public.challenge_diplomas.image_path IS
  'Issued: object name in bucket diplomas = {user_id}/{challenge_id}/{render_hash}.png (PNG+alpha). NULL = not rendered / admin reset.';
COMMENT ON COLUMN public.challenge_diplomas.render_hash IS
  'sha256(renderer_version, lang, headline, body, challenge_title, recipient_name_display, completed_at::date Europe/Prague, background_variant) – Edge.';
COMMENT ON COLUMN public.challenge_diplomas.period_from IS
  'AUDIT ONLY: Europe/Prague date of first verified place (participation.started_at). UI does NOT show "za N dní".';
COMMENT ON COLUMN public.challenge_diplomas.period_to IS
  'AUDIT ONLY: Europe/Prague date of last verified place (= completion day). Product label = "dokončeno dne dd.mm.yyyy" from completed_at (Edge/UI).';
COMMENT ON COLUMN public.challenge_diplomas.period_days IS
  'AUDIT ONLY: (period_to - period_from) + 1. Not shown in UI (SPEC: always "dokončeno dne …").';

CREATE INDEX IF NOT EXISTS challenge_diplomas_unrendered_idx
  ON public.challenge_diplomas (issued_at)
  WHERE user_id IS NOT NULL AND image_path IS NULL AND revoked_at IS NULL;

-- ---------------------------------------------------------------------------
-- 2) Czech accusative – 1:1 port of sklonovani() (first name only)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.cs_accusative(p_full_name text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
SET search_path = ''
AS $$
DECLARE
  v_name text := btrim(coalesce(p_full_name, ''));
  v_first text;
  v_tail text;
  fl text;
  res text;
  v_irregular jsonb := '{"pavel":"pavla","jiří":"jiřího","karel":"karla","marek":"marka",
    "františek":"františka","hynek":"hynka","lukáš":"lukáše","mikuláš":"mikuláše",
    "ondřej":"ondřeje","matěj":"matěje","tomáš":"tomáše","alex":"alexe","felix":"felixe"}';
  v_male_a text[] := ARRAY['nikola','saša','ilja','luka','luca','mika','sása'];
  v_female boolean;
BEGIN
  IF v_name = '' THEN
    RETURN nullif(p_full_name, '');
  END IF;
  v_name := regexp_replace(v_name, '\s+', ' ', 'g');
  v_first := split_part(v_name, ' ', 1);
  v_tail := nullif(substr(v_name, char_length(v_first) + 2), '');
  fl := lower(v_first);

  IF v_irregular ? fl THEN
    res := v_irregular ->> fl;
  ELSE
    v_female := NOT (fl = ANY (v_male_a))
                AND (fl ~ '(a|á|ia)$' OR fl ~ 'ie$');
    IF v_female THEN
      IF fl ~ '(a|á)$' THEN res := left(fl, -1) || 'u';
      ELSIF fl ~ 'ie$' THEN res := left(fl, -2) || 'ii';
      ELSE res := fl; END IF;
    ELSE
      IF fl ~ 'ek$' THEN res := left(fl, -2) || 'ka';
      ELSIF fl = ANY (v_male_a) THEN res := left(fl, -1) || 'u';
      ELSIF fl ~ 'o$' THEN res := left(fl, -1) || 'a';
      ELSIF fl ~ '(š|č|ž|j|x|s|z|c)$' THEN res := fl || 'e';
      ELSE res := fl || 'a'; END IF;
    END IF;
  END IF;

  IF v_first = upper(v_first) AND v_first <> lower(v_first) THEN
    res := upper(res);
  ELSIF v_first = initcap(v_first) THEN
    res := upper(left(res, 1)) || substr(res, 2);
  END IF;

  RETURN res || coalesce(' ' || v_tail, '');
END;
$$;
COMMENT ON FUNCTION private.cs_accusative(text) IS
  'Port of diplom_generator_original.py sklonovani(): FIRST name → accusative (pro Pavla / Janu / Marii). Surname untouched. Used only at issue time.';
REVOKE ALL ON FUNCTION private.cs_accusative(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.cs_accusative(text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3) Entitlement
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.diploma_entitled(p_user_id uuid, p_challenge_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
           SELECT 1 FROM public.challenge_participations cp
            WHERE cp.user_id = p_user_id AND cp.challenge_id = p_challenge_id
              AND cp.status = 'completed')
     AND (
           EXISTS (SELECT 1 FROM public.purchases pu
                    WHERE pu.user_id = p_user_id AND pu.challenge_id = p_challenge_id
                      AND pu.status = 'paid')
        OR EXISTS (SELECT 1 FROM public.challenge_prices pr
                    WHERE pr.challenge_id = p_challenge_id AND pr.status = 'published'
                      AND pr.diploma_price_cents = 0
                      AND now() <@ tstzrange(pr.valid_from, coalesce(pr.valid_to, 'infinity'::timestamptz), '[)'))
        OR (EXISTS (SELECT 1 FROM public.challenges c
                     WHERE c.id = p_challenge_id AND c.pricing_type = 'free')
            AND NOT EXISTS (SELECT 1 FROM public.challenge_prices pr
                             WHERE pr.challenge_id = p_challenge_id AND pr.status = 'published'
                               AND now() <@ tstzrange(pr.valid_from, coalesce(pr.valid_to, 'infinity'::timestamptz), '[)')))
     );
$$;
COMMENT ON FUNCTION private.diploma_entitled(uuid, uuid) IS
  'Full PNG entitlement: participation completed AND (paid purchase any variant OR active published diploma_price_cents = 0 OR free challenge without price row). Promo display prices are NOT entitlement.';
REVOKE ALL ON FUNCTION private.diploma_entitled(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.diploma_entitled(uuid, uuid) TO service_role;

-- ---------------------------------------------------------------------------
-- 4) Issue (re-defines 0024; same signature for verify_waypoint 0025/0027)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.issue_challenge_diploma(p_user_id uuid, p_challenge_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_part public.challenge_participations%ROWTYPE;
  v_lang text;
  v_title text;
  v_tmpl public.challenge_diplomas%ROWTYPE;
  v_name text;
  v_purchase_id uuid;
  v_variant text;
  v_id uuid;
  v_dlang text;
BEGIN
  SELECT d.id INTO v_id FROM public.challenge_diplomas d
   WHERE d.challenge_id = p_challenge_id AND d.user_id = p_user_id;
  IF FOUND THEN
    RETURN v_id;
  END IF;

  SELECT * INTO v_part FROM public.challenge_participations cp
   WHERE cp.user_id = p_user_id AND cp.challenge_id = p_challenge_id AND cp.status = 'completed';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'challenge not completed';
  END IF;

  SELECT coalesce(p.locale, 'cs'), nullif(btrim(p.display_name), '')
    INTO v_lang, v_name
    FROM public.profiles p WHERE p.id = p_user_id;
  v_lang := coalesce(v_lang, 'cs');
  -- v1 product = cs only (SPEC §6); still snapshot actual locale for future en/de
  v_dlang := v_lang;

  SELECT private.pick_locale(t.title_cs, t.title_en, t.title_de, v_lang) INTO v_title
    FROM public.challenge_titles t
   WHERE t.challenge_id = p_challenge_id AND t.status = 'published'
     AND now() <@ tstzrange(t.valid_from, coalesce(t.valid_to, 'infinity'::timestamptz), '[)')
   LIMIT 1;

  SELECT d.* INTO v_tmpl
    FROM public.challenge_diplomas d
   WHERE d.challenge_id = p_challenge_id AND d.user_id IS NULL AND d.status = 'published'
     AND d.lang = v_dlang
     AND now() <@ tstzrange(d.valid_from, coalesce(d.valid_to, 'infinity'::timestamptz), '[)')
   LIMIT 1;

  SELECT pu.id, pu.reward_variant INTO v_purchase_id, v_variant
    FROM public.purchases pu
   WHERE pu.user_id = p_user_id AND pu.challenge_id = p_challenge_id AND pu.status = 'paid'
   ORDER BY pu.paid_at DESC NULLS LAST
   LIMIT 1;

  INSERT INTO public.challenge_diplomas (
    challenge_id, user_id, template_id, participation_id, lang, headline, body,
    recipient_name, recipient_name_display, challenge_title, completed_at, duration,
    period_from, period_to, background_variant,
    reward_variant, purchase_id, issued_at)
  VALUES (
    p_challenge_id, p_user_id, v_tmpl.id, v_part.id, v_dlang,
    coalesce(nullif(btrim(v_tmpl.headline), ''), ''),
    coalesce(v_tmpl.body, ''),
    v_name,
    CASE WHEN v_name IS NULL THEN NULL
         WHEN v_dlang = 'cs' THEN left(private.cs_accusative(v_name), 80)
         ELSE left(v_name, 80) END,
    coalesce(v_title, ''), v_part.completed_at, v_part.duration,
    (v_part.started_at AT TIME ZONE 'Europe/Prague')::date,
    (v_part.completed_at AT TIME ZONE 'Europe/Prague')::date,
    (1 + floor(random() * 4))::smallint,
    v_variant, v_purchase_id, now())
  ON CONFLICT (challenge_id, user_id) WHERE (user_id IS NOT NULL) DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    SELECT d.id INTO v_id FROM public.challenge_diplomas d
     WHERE d.challenge_id = p_challenge_id AND d.user_id = p_user_id;
  END IF;
  RETURN v_id;
END;
$$;
COMMENT ON FUNCTION private.issue_challenge_diploma(uuid, uuid) IS
  'Idempotent issue of diploma RECORD at completion (verify_waypoint). Snapshots name (raw + cs accusative), title, template text, period audit dates, random background 1–4. No entitlement check; no rendering; no name edits afterwards.';
REVOKE ALL ON FUNCTION private.issue_challenge_diploma(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.issue_challenge_diploma(uuid, uuid) TO service_role;

-- Back-fill rows issued before this migration, then validate
UPDATE public.challenge_diplomas d
   SET background_variant = (1 + floor(random() * 4))::smallint
 WHERE d.user_id IS NOT NULL AND d.background_variant IS NULL;
UPDATE public.challenge_diplomas d
   SET recipient_name_display = CASE WHEN d.lang = 'cs' THEN left(private.cs_accusative(d.recipient_name), 80)
                                     ELSE left(d.recipient_name, 80) END
 WHERE d.user_id IS NOT NULL AND d.recipient_name_display IS NULL
   AND nullif(btrim(d.recipient_name), '') IS NOT NULL;
UPDATE public.challenge_diplomas d
   SET period_from = (cp.started_at AT TIME ZONE 'Europe/Prague')::date,
       period_to   = (cp.completed_at AT TIME ZONE 'Europe/Prague')::date
  FROM public.challenge_participations cp
 WHERE d.user_id IS NOT NULL AND d.period_to IS NULL AND cp.id = d.participation_id;
ALTER TABLE public.challenge_diplomas VALIDATE CONSTRAINT challenge_diplomas_issued_background;

-- ---------------------------------------------------------------------------
-- 5) Client RPC: diploma_status (no set_diploma_name)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.diploma_status(p_challenge_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  d public.challenge_diplomas%ROWTYPE;
  v_state text;
  v_day text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  SELECT * INTO d FROM public.challenge_diplomas
   WHERE challenge_id = p_challenge_id AND user_id = v_uid;
  IF d.completed_at IS NOT NULL THEN
    v_day := to_char((d.completed_at AT TIME ZONE 'Europe/Prague')::date, 'DD.MM.YYYY');
  END IF;
  v_state := CASE
    WHEN d.id IS NULL THEN 'locked'
    WHEN d.revoked_at IS NOT NULL THEN 'revoked'
    WHEN NOT private.diploma_entitled(v_uid, p_challenge_id) THEN 'buy'          -- UI: blurred + CTA
    WHEN d.recipient_name_display IS NULL THEN 'need_name'                       -- fill profiles.display_name
    WHEN d.image_path IS NULL THEN 'render'
    ELSE 'ready' END;
  RETURN jsonb_build_object(
    'state', v_state,
    'diploma_id', d.id,
    'lang', d.lang,
    'recipient_name_display', d.recipient_name_display,
    'completion_day_label', CASE WHEN v_day IS NULL THEN NULL
                                 ELSE 'dokončeno dne ' || v_day END,             -- product copy (cs v1)
    'completed_on', (d.completed_at AT TIME ZONE 'Europe/Prague')::date,
    'rendered_at', d.rendered_at);
END;
$$;
COMMENT ON FUNCTION public.diploma_status(uuid) IS
  'UI state for /diploma/:id (SPEC §8): locked | buy (blurred) | need_name | render | ready | revoked. completion_day_label = "dokončeno dne dd.mm.yyyy". No name edits.';
REVOKE ALL ON FUNCTION public.diploma_status(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.diploma_status(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6) Edge commit (service_role only) – PNG paths
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_diploma_render(
  p_diploma_id uuid, p_render_hash text, p_image_path text, p_renderer_version integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  d public.challenge_diplomas%ROWTYPE;
  v_expected text;
BEGIN
  IF p_render_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'render_hash must be sha256 hex' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO d FROM public.challenge_diplomas WHERE id = p_diploma_id AND user_id IS NOT NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'diploma not found' USING ERRCODE = 'P0002';
  END IF;
  IF d.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'diploma revoked' USING ERRCODE = '42501';
  END IF;
  IF NOT private.diploma_entitled(d.user_id, d.challenge_id) THEN
    RAISE EXCEPTION 'not_entitled' USING ERRCODE = '42501';
  END IF;
  v_expected := d.user_id::text || '/' || d.challenge_id::text || '/' || p_render_hash || '.png';
  IF p_image_path IS DISTINCT FROM v_expected THEN
    RAISE EXCEPTION 'image_path must be {user_id}/{challenge_id}/{render_hash}.png' USING ERRCODE = '22023';
  END IF;
  IF d.render_hash IS NOT DISTINCT FROM p_render_hash THEN
    RETURN jsonb_build_object('updated', false, 'previous_image_path', NULL);
  END IF;
  UPDATE public.challenge_diplomas
     SET image_path = p_image_path, render_hash = p_render_hash,
         rendered_at = now(), renderer_version = p_renderer_version
   WHERE id = d.id;
  RETURN jsonb_build_object('updated', true, 'previous_image_path', d.image_path);
END;
$$;
COMMENT ON FUNCTION public.record_diploma_render(uuid, text, text, integer) IS
  'Edge diploma (service_role ONLY; public schema for PostgREST): commit PNG render. Re-checks entitlement + path …/{hash}.png; returns previous_image_path to delete. No-op when hash unchanged.';
REVOKE ALL ON FUNCTION public.record_diploma_render(uuid, text, text, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_diploma_render(uuid, text, text, integer) TO service_role;

-- ---------------------------------------------------------------------------
-- 7) Storage: buckets + policies (PNG)
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('diplomas', 'diplomas', false, 2097152, ARRAY['image/png']),
       ('diploma-assets', 'diploma-assets', false, 5242880,
        ARRAY['image/jpeg', 'image/png', 'font/ttf', 'application/x-font-ttf', 'application/octet-stream'])
ON CONFLICT (id) DO UPDATE
  SET public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

DROP POLICY IF EXISTS "diplomas owner read" ON storage.objects;
CREATE POLICY "diplomas owner read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'diplomas'
         AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);
-- diploma-assets: no policies → service_role only

-- =============================================================================
-- ROLLBACK (manual; undeploy Edge `diploma` FIRST)
-- =============================================================================
-- DROP POLICY IF EXISTS "diplomas owner read" ON storage.objects;
-- DELETE FROM storage.buckets WHERE id IN ('diplomas', 'diploma-assets');  -- empty objects first
-- DROP FUNCTION IF EXISTS public.record_diploma_render(uuid, text, text, integer);
-- DROP FUNCTION IF EXISTS public.diploma_status(uuid);
-- DROP FUNCTION IF EXISTS public.set_diploma_name(uuid, text);  -- already dropped in forward
-- DROP FUNCTION IF EXISTS private.diploma_entitled(uuid, uuid);
-- -- restore private.issue_challenge_diploma from redesign 0024 BEFORE dropping columns
-- DROP FUNCTION IF EXISTS private.cs_accusative(text);
-- DROP INDEX IF EXISTS public.challenge_diplomas_unrendered_idx;
-- ALTER TABLE public.challenge_diplomas
--   DROP CONSTRAINT IF EXISTS challenge_diplomas_issued_background,
--   DROP CONSTRAINT IF EXISTS challenge_diplomas_render_issued_only,
--   DROP CONSTRAINT IF EXISTS challenge_diplomas_render_coherent,
--   DROP CONSTRAINT IF EXISTS challenge_diplomas_period_check,
--   DROP CONSTRAINT IF EXISTS challenge_diplomas_display_name_check,
--   DROP CONSTRAINT IF EXISTS challenge_diplomas_background_variant_check;
-- ALTER TABLE public.challenge_diplomas
--   DROP COLUMN IF EXISTS period_days, DROP COLUMN IF EXISTS period_to, DROP COLUMN IF EXISTS period_from,
--   DROP COLUMN IF EXISTS name_edits,
--   DROP COLUMN IF EXISTS renderer_version, DROP COLUMN IF EXISTS rendered_at,
--   DROP COLUMN IF EXISTS render_hash, DROP COLUMN IF EXISTS image_path,
--   DROP COLUMN IF EXISTS background_variant, DROP COLUMN IF EXISTS recipient_name_display;
-- =============================================================================
