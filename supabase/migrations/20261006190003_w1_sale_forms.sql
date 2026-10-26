-- =============================================================================
-- 0023_w1_sale_forms.sql                         (SPEC §4 W1 – expand, part 3)
-- READY FOR REPO – NOT APPLIED on prod (await Ondřej apply OK)  |  Viateria yzmbxxgesnbsqygzgdky
-- challenge_sale_forms (SPEC §2.6 v2): FAPI form per challenge × locale ×
-- reward_variant. NO promo_stripe_id (promo discount lives in a normal FAPI form).
-- fapi_form_url = browser URL (?id=<path UUID>); fapi_form_id = numeric FAPI id
-- (filled by sync; FAPI has no lookup by path). Optional fapi_form_path = UUID
-- parsed from URL for convenience. Backfill from fapi_form_url_* as locale 'cs'.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.challenge_sale_forms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL REFERENCES public.challenges (id) ON DELETE CASCADE,
  locale text NOT NULL CHECK (locale = ANY (ARRAY['cs', 'en', 'de'])),
  reward_variant text NOT NULL CHECK (reward_variant = ANY (ARRAY['diploma', 'medal_and_diploma'])),
  fapi_form_url text NOT NULL CHECK (fapi_form_url ~* '^https?://[^[:space:]]+$'),
  fapi_form_id integer,            -- numeric FAPI form id; sync fills via /forms/ match on path
  fapi_form_path uuid,             -- UUID from ?id= query; derived on write (no FAPI path lookup)
  status text NOT NULL DEFAULT 'draft'
    CHECK (status = ANY (ARRAY['draft', 'published', 'archived'])),
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT challenge_sale_forms_valid_range CHECK (valid_to IS NULL OR valid_to > valid_from),
  CONSTRAINT challenge_sale_forms_one_published EXCLUDE USING gist (
    challenge_id WITH =,
    locale WITH =,
    reward_variant WITH =,
    tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)') WITH &&
  ) WHERE (status = 'published')
);

-- Idempotent upgrade from v1 draft (had promo_stripe_id, lacked fapi_form_id)
ALTER TABLE public.challenge_sale_forms DROP CONSTRAINT IF EXISTS challenge_sale_forms_one_published;
ALTER TABLE public.challenge_sale_forms DROP COLUMN IF EXISTS promo_stripe_id;
ALTER TABLE public.challenge_sale_forms ADD COLUMN IF NOT EXISTS fapi_form_id integer;
ALTER TABLE public.challenge_sale_forms ADD COLUMN IF NOT EXISTS fapi_form_path uuid;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                 WHERE conrelid = 'public.challenge_sale_forms'::regclass
                   AND conname = 'challenge_sale_forms_one_published') THEN
    ALTER TABLE public.challenge_sale_forms ADD CONSTRAINT challenge_sale_forms_one_published
      EXCLUDE USING gist (
        challenge_id WITH =,
        locale WITH =,
        reward_variant WITH =,
        tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)') WITH &&
      ) WHERE (status = 'published');
  END IF;
END $$;

COMMENT ON TABLE public.challenge_sale_forms IS
  'FAPI sales form per challenge × locale × reward_variant. Resolve: user locale → cs → en → de. Promo discount = code inside the normal FAPI form (no separate promo rows).';
COMMENT ON COLUMN public.challenge_sale_forms.fapi_form_url IS
  'Full checkout URL; ?id= holds the FAPI form path (UUID). FAPI has no lookup by path → keep URL.';
COMMENT ON COLUMN public.challenge_sale_forms.fapi_form_id IS
  'Numeric FAPI form id. Filled by sync-fapi-prices (scan /forms/, match path from URL). Needed for item_templates?form=<id>.';
COMMENT ON COLUMN public.challenge_sale_forms.fapi_form_path IS
  'UUID parsed from fapi_form_url ?id=; convenience for sync matching. NULL if URL has no id=.';

CREATE OR REPLACE FUNCTION private.derive_fapi_form_path()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  v text;
BEGIN
  v := substring(NEW.fapi_form_url from '(?i)[?&]id=([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})');
  IF v IS NOT NULL THEN
    NEW.fapi_form_path := v::uuid;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS challenge_sale_forms_derive_path ON public.challenge_sale_forms;
CREATE TRIGGER challenge_sale_forms_derive_path
  BEFORE INSERT OR UPDATE OF fapi_form_url ON public.challenge_sale_forms
  FOR EACH ROW EXECUTE FUNCTION private.derive_fapi_form_path();

CREATE INDEX IF NOT EXISTS challenge_sale_forms_challenge_idx
  ON public.challenge_sale_forms (challenge_id, reward_variant, locale);
CREATE INDEX IF NOT EXISTS challenge_sale_forms_fapi_form_id_idx
  ON public.challenge_sale_forms (fapi_form_id) WHERE fapi_form_id IS NOT NULL;
DROP INDEX IF EXISTS public.challenge_sale_forms_promo_idx;

DROP TRIGGER IF EXISTS challenge_sale_forms_touch ON public.challenge_sale_forms;
CREATE TRIGGER challenge_sale_forms_touch BEFORE UPDATE ON public.challenge_sale_forms
  FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();

ALTER TABLE public.challenge_sale_forms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "published sale forms of readable challenges" ON public.challenge_sale_forms;
CREATE POLICY "published sale forms of readable challenges" ON public.challenge_sale_forms
  FOR SELECT TO authenticated
  USING (status = 'published' AND private.challenge_readable(challenge_id));
REVOKE ALL ON public.challenge_sale_forms FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.challenge_sale_forms FROM authenticated;
GRANT SELECT ON public.challenge_sale_forms TO authenticated;

INSERT INTO public.challenge_sale_forms (challenge_id, locale, reward_variant, fapi_form_url, status, valid_from)
SELECT c.id, 'cs', v.variant, btrim(v.url), 'published', c.created_at
FROM public.challenges c
CROSS JOIN LATERAL (VALUES ('diploma', c.fapi_form_url_diploma),
                           ('medal_and_diploma', c.fapi_form_url_medal)) AS v (variant, url)
WHERE btrim(coalesce(v.url, '')) ~* '^https?://[^[:space:]]+$'
  AND NOT EXISTS (SELECT 1 FROM public.challenge_sale_forms f
                  WHERE f.challenge_id = c.id AND f.locale = 'cs'
                    AND f.reward_variant = v.variant);

-- Resolver: locale → cs → en → de (no promo form branch)
CREATE OR REPLACE FUNCTION public.challenge_sale_form_url(
  p_challenge_id uuid,
  p_reward_variant text,
  p_locale text DEFAULT NULL
)
RETURNS text
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO 'public'
AS $$
  WITH me AS (
    SELECT coalesce(p_locale,
                    (SELECT pr.locale FROM public.profiles pr WHERE pr.id = (SELECT auth.uid())),
                    'cs') AS locale
  )
  SELECT f.fapi_form_url
  FROM public.challenge_sale_forms f, me
  WHERE f.challenge_id = p_challenge_id
    AND f.reward_variant = p_reward_variant
    AND f.status = 'published'
    AND now() <@ tstzrange(f.valid_from, coalesce(f.valid_to, 'infinity'::timestamptz), '[)')
  ORDER BY CASE WHEN f.locale = me.locale THEN 0
                WHEN f.locale = 'cs' THEN 1 WHEN f.locale = 'en' THEN 2 ELSE 3 END,
           f.valid_from DESC
  LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.challenge_sale_form_url(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.challenge_sale_form_url(uuid, text, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.refresh_legacy_challenge_forms(p_challenge_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM set_config('viateria.legacy_sync', 'on', true);
  UPDATE public.challenges c
     SET fapi_form_url_diploma = (
           SELECT f.fapi_form_url FROM public.challenge_sale_forms f
            WHERE f.challenge_id = c.id AND f.locale = 'cs' AND f.reward_variant = 'diploma'
              AND f.status = 'published'
              AND now() <@ tstzrange(f.valid_from, coalesce(f.valid_to, 'infinity'::timestamptz), '[)')
            LIMIT 1),
         fapi_form_url_medal = (
           SELECT f.fapi_form_url FROM public.challenge_sale_forms f
            WHERE f.challenge_id = c.id AND f.locale = 'cs' AND f.reward_variant = 'medal_and_diploma'
              AND f.status = 'published'
              AND now() <@ tstzrange(f.valid_from, coalesce(f.valid_to, 'infinity'::timestamptz), '[)')
            LIMIT 1),
         updated_at = now()
   WHERE c.id = p_challenge_id;
  PERFORM set_config('viateria.legacy_sync', 'off', true);
END;
$$;
REVOKE ALL ON FUNCTION private.refresh_legacy_challenge_forms(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.trg_refresh_legacy_challenge_forms()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM private.refresh_legacy_challenge_forms(coalesce(NEW.challenge_id, OLD.challenge_id));
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION private.trg_refresh_legacy_challenge_forms() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS challenge_sale_forms_legacy_sync ON public.challenge_sale_forms;
CREATE TRIGGER challenge_sale_forms_legacy_sync
  AFTER INSERT OR UPDATE OR DELETE ON public.challenge_sale_forms
  FOR EACH ROW EXECUTE FUNCTION private.trg_refresh_legacy_challenge_forms();

CREATE OR REPLACE FUNCTION private.guard_legacy_challenge_forms()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  IF current_setting('viateria.legacy_sync', true) = 'on' THEN
    RETURN NEW;
  END IF;
  IF (NEW.fapi_form_url_diploma, NEW.fapi_form_url_medal)
     IS DISTINCT FROM (OLD.fapi_form_url_diploma, OLD.fapi_form_url_medal) THEN
    RAISE EXCEPTION 'challenges.fapi_form_url_* are legacy copies since 0023 – edit challenge_sale_forms'
      USING ERRCODE = 'read_only_sql_transaction';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS challenges_form_guard ON public.challenges;
CREATE TRIGGER challenges_form_guard
  BEFORE UPDATE OF fapi_form_url_diploma, fapi_form_url_medal ON public.challenges
  FOR EACH ROW EXECUTE FUNCTION private.guard_legacy_challenge_forms();

CREATE OR REPLACE FUNCTION private.refresh_all_legacy_challenge_copies()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT id FROM public.challenges LOOP
    PERFORM private.refresh_legacy_challenge_i18n(r.id);
    PERFORM private.refresh_legacy_challenge_prices(r.id);
    PERFORM private.refresh_legacy_challenge_forms(r.id);
  END LOOP;
END;
$$;

-- =============================================================================
-- ROLLBACK (manual)
-- =============================================================================
-- DROP TRIGGER IF EXISTS challenges_form_guard ON public.challenges;
-- DROP TRIGGER IF EXISTS challenge_sale_forms_legacy_sync ON public.challenge_sale_forms;
-- DROP FUNCTION IF EXISTS private.guard_legacy_challenge_forms(), private.trg_refresh_legacy_challenge_forms(),
--   private.refresh_legacy_challenge_forms(uuid), private.derive_fapi_form_path();
-- DROP FUNCTION IF EXISTS public.challenge_sale_form_url(uuid, text, text);
-- DROP TABLE IF EXISTS public.challenge_sale_forms;
-- =============================================================================
