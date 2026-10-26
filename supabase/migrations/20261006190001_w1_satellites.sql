-- =============================================================================
-- 0021_w1_satellites.sql                         (SPEC §4 W1 – expand, part 1)
-- READY FOR REPO – NOT APPLIED on prod (await Ondřej apply OK)  |  Viateria yzmbxxgesnbsqygzgdky
-- btree_gist, private.pick_locale, challenges.valid_from/valid_to/length,
-- satellites challenge_titles / challenge_descriptions / challenge_prices
-- (empty – backfill in 0022). Purely additive.
-- SPEC v2: descriptions = desc only (NO diploma_*); diploma templates live in
-- challenge_diplomas (0024). Prices: WIDE + vat_rate + including_vat +
-- fapi_product_id_diploma/_medal (FAPI cache). Languages permanently cs/en/de.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION private.pick_locale(p_cs text, p_en text, p_de text, p_preferred text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path TO 'public'
AS $$
  SELECT COALESCE(
    CASE lower(coalesce(p_preferred, ''))
      WHEN 'cs' THEN nullif(btrim(p_cs), '')
      WHEN 'en' THEN nullif(btrim(p_en), '')
      WHEN 'de' THEN nullif(btrim(p_de), '')
    END,
    nullif(btrim(p_cs), ''),
    nullif(btrim(p_en), ''),
    nullif(btrim(p_de), '')
  );
$$;
COMMENT ON FUNCTION private.pick_locale(text, text, text, text) IS
  'Pick localized text from wide cs/en/de columns: preferred → cs → en → de. Blank = missing.';
REVOKE ALL ON FUNCTION private.pick_locale(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.pick_locale(text, text, text, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- challenges: valid_from / valid_to + length (synced with starts_at/ends_at until W4)
ALTER TABLE public.challenges ADD COLUMN IF NOT EXISTS valid_from timestamptz;
ALTER TABLE public.challenges ADD COLUMN IF NOT EXISTS valid_to timestamptz;
ALTER TABLE public.challenges ADD COLUMN IF NOT EXISTS length text;

ALTER TABLE public.challenges DROP CONSTRAINT IF EXISTS challenges_length_check;
ALTER TABLE public.challenges ADD CONSTRAINT challenges_length_check
  CHECK (length IS NULL OR length = ANY (ARRAY['short', 'medium', 'long']));
ALTER TABLE public.challenges DROP CONSTRAINT IF EXISTS challenges_valid_range;
ALTER TABLE public.challenges ADD CONSTRAINT challenges_valid_range
  CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to > valid_from);
COMMENT ON COLUMN public.challenges.valid_from IS 'Diagram valid_from. Synced with starts_at until W4.';
COMMENT ON COLUMN public.challenges.valid_to IS 'Diagram valid_to. Synced with ends_at until W4.';
COMMENT ON COLUMN public.challenges.length IS 'Catalog length bucket short|medium|long. Nullable; filled in dashboard.';

UPDATE public.challenges
   SET valid_from = starts_at, valid_to = ends_at
 WHERE valid_from IS DISTINCT FROM starts_at OR valid_to IS DISTINCT FROM ends_at;

CREATE OR REPLACE FUNCTION private.sync_challenge_validity()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.valid_from := coalesce(NEW.valid_from, NEW.starts_at);
    NEW.starts_at  := coalesce(NEW.starts_at, NEW.valid_from);
    NEW.valid_to   := coalesce(NEW.valid_to, NEW.ends_at);
    NEW.ends_at    := coalesce(NEW.ends_at, NEW.valid_to);
  ELSE
    IF NEW.valid_from IS DISTINCT FROM OLD.valid_from THEN NEW.starts_at := NEW.valid_from;
    ELSIF NEW.starts_at IS DISTINCT FROM OLD.starts_at THEN NEW.valid_from := NEW.starts_at; END IF;
    IF NEW.valid_to IS DISTINCT FROM OLD.valid_to THEN NEW.ends_at := NEW.valid_to;
    ELSIF NEW.ends_at IS DISTINCT FROM OLD.ends_at THEN NEW.valid_to := NEW.ends_at; END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS challenges_sync_validity ON public.challenges;
CREATE TRIGGER challenges_sync_validity
  BEFORE INSERT OR UPDATE OF valid_from, valid_to, starts_at, ends_at ON public.challenges
  FOR EACH ROW EXECUTE FUNCTION private.sync_challenge_validity();

-- challenge_titles
CREATE TABLE IF NOT EXISTS public.challenge_titles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL REFERENCES public.challenges (id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status = ANY (ARRAY['draft', 'published', 'archived'])),
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  title_cs text NOT NULL CHECK (btrim(title_cs) <> ''),
  title_en text,
  title_de text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT challenge_titles_valid_range CHECK (valid_to IS NULL OR valid_to > valid_from),
  CONSTRAINT challenge_titles_one_published EXCLUDE USING gist (
    challenge_id WITH =,
    tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)') WITH &&
  ) WHERE (status = 'published')
);
COMMENT ON TABLE public.challenge_titles IS
  'Diagram "titles". Wide cs/en/de (languages permanent). Active = published ∧ now() ∈ [valid_from, valid_to).';
CREATE INDEX IF NOT EXISTS challenge_titles_challenge_idx
  ON public.challenge_titles (challenge_id, valid_from DESC);

-- challenge_descriptions (SPEC v2: NO diploma_* — templates in challenge_diplomas)
CREATE TABLE IF NOT EXISTS public.challenge_descriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL REFERENCES public.challenges (id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status = ANY (ARRAY['draft', 'published', 'archived'])),
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  desc_cs text NOT NULL DEFAULT '',
  desc_en text,
  desc_de text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT challenge_descriptions_valid_range CHECK (valid_to IS NULL OR valid_to > valid_from),
  CONSTRAINT challenge_descriptions_one_published EXCLUDE USING gist (
    challenge_id WITH =,
    tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)') WITH &&
  ) WHERE (status = 'published')
);
COMMENT ON TABLE public.challenge_descriptions IS
  'Diagram "descrip". Wide desc_cs/en/de only. Diploma template lives in challenge_diplomas (user_id IS NULL).';
CREATE INDEX IF NOT EXISTS challenge_descriptions_challenge_idx
  ON public.challenge_descriptions (challenge_id, valid_from DESC);

-- Idempotent upgrade path if an earlier draft created diploma_* columns
ALTER TABLE public.challenge_descriptions DROP COLUMN IF EXISTS diploma_headline_cs;
ALTER TABLE public.challenge_descriptions DROP COLUMN IF EXISTS diploma_headline_en;
ALTER TABLE public.challenge_descriptions DROP COLUMN IF EXISTS diploma_headline_de;
ALTER TABLE public.challenge_descriptions DROP COLUMN IF EXISTS diploma_body_cs;
ALTER TABLE public.challenge_descriptions DROP COLUMN IF EXISTS diploma_body_en;
ALTER TABLE public.challenge_descriptions DROP COLUMN IF EXISTS diploma_body_de;

-- challenge_prices – WIDE FAPI cache + VAT
CREATE TABLE IF NOT EXISTS public.challenge_prices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL REFERENCES public.challenges (id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status = ANY (ARRAY['draft', 'published', 'archived'])),
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  diploma_price_cents integer NOT NULL CHECK (diploma_price_cents >= 0),
  medal_price_cents integer CHECK (medal_price_cents IS NULL OR medal_price_cents >= 0),
  currency text NOT NULL CHECK (currency = ANY (ARRAY['czk', 'eur'])),
  -- VAT: FAPI item_templates expose vat + including_vat; cents are display amounts
  vat_rate numeric(5,2) CHECK (vat_rate IS NULL OR (vat_rate >= 0 AND vat_rate <= 100)),
  including_vat boolean NOT NULL DEFAULT true,
  source text NOT NULL DEFAULT 'manual' CHECK (source = ANY (ARRAY['fapi', 'manual'])),
  fapi_product_id_diploma text,   -- FAPI item/product id for diploma SKU (SPEC §2.5)
  fapi_product_id_medal text,     -- FAPI item/product id for medal+diploma SKU
  fapi_payload_hash text,
  synced_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT challenge_prices_valid_range CHECK (valid_to IS NULL OR valid_to > valid_from),
  CONSTRAINT challenge_prices_fapi_ref CHECK (
    source <> 'fapi' OR fapi_product_id_diploma IS NOT NULL OR fapi_product_id_medal IS NOT NULL),
  CONSTRAINT challenge_prices_one_published EXCLUDE USING gist (
    challenge_id WITH =,
    tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)') WITH &&
  ) WHERE (status = 'published')
);
-- Idempotent: add VAT cols if table already existed from v1 draft
ALTER TABLE public.challenge_prices ADD COLUMN IF NOT EXISTS vat_rate numeric(5,2);
ALTER TABLE public.challenge_prices ADD COLUMN IF NOT EXISTS including_vat boolean;
UPDATE public.challenge_prices SET including_vat = true WHERE including_vat IS NULL;
ALTER TABLE public.challenge_prices ALTER COLUMN including_vat SET DEFAULT true;
ALTER TABLE public.challenge_prices ALTER COLUMN including_vat SET NOT NULL;
COMMENT ON TABLE public.challenge_prices IS
  'Diagram "prices". CACHE of FAPI list prices (FAPI = SoT). Sync: GET forms → items[].item_template → item_templates?form=<id> prices[] {type,price,currency_code} + vat + including_vat; sum mandatory one_time; polling only (daily+manual). source=manual fallback. Promo = discount code in the normal FAPI form (promo_stripes.promo_*_price_cents = display overlay only).';
COMMENT ON COLUMN public.challenge_prices.including_vat IS
  'true = diploma/medal_price_cents are gross (FAPI including_vat); false = net. App displays cents as stored.';
COMMENT ON COLUMN public.challenge_prices.vat_rate IS
  'VAT percent from FAPI item_template.vat (e.g. 21.00). NULL when unknown / manual without VAT.';
CREATE INDEX IF NOT EXISTS challenge_prices_challenge_idx
  ON public.challenge_prices (challenge_id, valid_from DESC);

DROP TRIGGER IF EXISTS challenge_titles_touch ON public.challenge_titles;
CREATE TRIGGER challenge_titles_touch BEFORE UPDATE ON public.challenge_titles
  FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
DROP TRIGGER IF EXISTS challenge_descriptions_touch ON public.challenge_descriptions;
CREATE TRIGGER challenge_descriptions_touch BEFORE UPDATE ON public.challenge_descriptions
  FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
DROP TRIGGER IF EXISTS challenge_prices_touch ON public.challenge_prices;
CREATE TRIGGER challenge_prices_touch BEFORE UPDATE ON public.challenge_prices
  FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();

ALTER TABLE public.challenge_titles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_descriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_prices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "published titles of readable challenges" ON public.challenge_titles;
CREATE POLICY "published titles of readable challenges" ON public.challenge_titles
  FOR SELECT TO authenticated
  USING (status = 'published' AND private.challenge_readable(challenge_id));
DROP POLICY IF EXISTS "published descriptions of readable challenges" ON public.challenge_descriptions;
CREATE POLICY "published descriptions of readable challenges" ON public.challenge_descriptions
  FOR SELECT TO authenticated
  USING (status = 'published' AND private.challenge_readable(challenge_id));
DROP POLICY IF EXISTS "published prices of readable challenges" ON public.challenge_prices;
CREATE POLICY "published prices of readable challenges" ON public.challenge_prices
  FOR SELECT TO authenticated
  USING (status = 'published' AND private.challenge_readable(challenge_id));

REVOKE ALL ON public.challenge_titles, public.challenge_descriptions, public.challenge_prices FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE
  ON public.challenge_titles, public.challenge_descriptions, public.challenge_prices FROM authenticated;
GRANT SELECT ON public.challenge_titles, public.challenge_descriptions, public.challenge_prices TO authenticated;

-- =============================================================================
-- ROLLBACK (manual)
-- =============================================================================
-- DROP TABLE IF EXISTS public.challenge_prices, public.challenge_descriptions, public.challenge_titles;
-- DROP TRIGGER IF EXISTS challenges_sync_validity ON public.challenges;
-- DROP FUNCTION IF EXISTS private.sync_challenge_validity();
-- ALTER TABLE public.challenges DROP CONSTRAINT IF EXISTS challenges_valid_range,
--   DROP CONSTRAINT IF EXISTS challenges_length_check;
-- ALTER TABLE public.challenges DROP COLUMN IF EXISTS length, DROP COLUMN IF EXISTS valid_to,
--   DROP COLUMN IF EXISTS valid_from;
-- DROP FUNCTION IF EXISTS private.touch_updated_at();
-- DROP FUNCTION IF EXISTS private.pick_locale(text, text, text, text);
-- =============================================================================
