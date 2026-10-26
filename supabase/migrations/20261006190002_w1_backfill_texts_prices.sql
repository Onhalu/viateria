-- =============================================================================
-- 0022_w1_backfill_texts_prices.sql              (SPEC §4 W1 – expand, part 2)
-- READY FOR REPO – NOT APPLIED on prod (await Ondřej apply OK)  |  Viateria yzmbxxgesnbsqygzgdky
-- Backfill challenge_titles / challenge_descriptions from challenge_i18n,
-- challenge_prices from challenges.*_price_cents (+ VAT defaults).
-- Diploma template backfill → 0024 (challenge_diplomas rows with user_id IS NULL).
-- From here satellites are the ONLY place to edit (single SoT): reverse-sync +
-- guard triggers. Bypass GUC: viateria.legacy_sync = 'on'.
-- Live: challenge_i18n 15 rows; diploma_* all NULL; paid challenges ~7.
-- =============================================================================

INSERT INTO public.challenge_titles (challenge_id, status, valid_from, title_cs, title_en, title_de)
SELECT c.id, 'published', c.created_at,
       max(i.title) FILTER (WHERE i.locale = 'cs'),
       max(i.title) FILTER (WHERE i.locale = 'en'),
       max(i.title) FILTER (WHERE i.locale = 'de')
FROM public.challenges c
JOIN public.challenge_i18n i ON i.challenge_id = c.id
WHERE NOT EXISTS (SELECT 1 FROM public.challenge_titles t WHERE t.challenge_id = c.id)
GROUP BY c.id, c.created_at
HAVING nullif(btrim(max(i.title) FILTER (WHERE i.locale = 'cs')), '') IS NOT NULL;

INSERT INTO public.challenge_descriptions (
  challenge_id, status, valid_from, desc_cs, desc_en, desc_de)
SELECT c.id, 'published', c.created_at,
       coalesce(max(i.description) FILTER (WHERE i.locale = 'cs'), ''),
       max(i.description) FILTER (WHERE i.locale = 'en'),
       max(i.description) FILTER (WHERE i.locale = 'de')
FROM public.challenges c
JOIN public.challenge_i18n i ON i.challenge_id = c.id
WHERE NOT EXISTS (SELECT 1 FROM public.challenge_descriptions d WHERE d.challenge_id = c.id)
GROUP BY c.id, c.created_at;

-- Prices: paid only. source='manual' until first FAPI sync. VAT unknown on legacy → including_vat=true, vat_rate NULL.
INSERT INTO public.challenge_prices (challenge_id, status, valid_from,
  diploma_price_cents, medal_price_cents, currency, including_vat, vat_rate, source, synced_at)
SELECT c.id, 'published', c.created_at,
       c.diploma_price_cents, nullif(c.medal_price_cents, 0), lower(c.currency),
       true, NULL, 'manual', NULL
FROM public.challenges c
WHERE c.pricing_type = 'paid'
  AND NOT EXISTS (SELECT 1 FROM public.challenge_prices p WHERE p.challenge_id = c.id);

-- Reverse sync: active title+description → challenge_i18n (diploma_* filled later from templates in 0024)
CREATE OR REPLACE FUNCTION private.refresh_legacy_challenge_i18n(p_challenge_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  t public.challenge_titles%ROWTYPE;
  d public.challenge_descriptions%ROWTYPE;
  v_headline_cs text; v_headline_en text; v_headline_de text;
  v_body_cs text; v_body_en text; v_body_de text;
BEGIN
  PERFORM set_config('viateria.legacy_sync', 'on', true);

  SELECT * INTO t FROM public.challenge_titles
   WHERE challenge_id = p_challenge_id AND status = 'published'
     AND now() <@ tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)')
   LIMIT 1;
  SELECT * INTO d FROM public.challenge_descriptions
   WHERE challenge_id = p_challenge_id AND status = 'published'
     AND now() <@ tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)')
   LIMIT 1;

  IF t.id IS NULL THEN
    PERFORM set_config('viateria.legacy_sync', 'off', true);
    RETURN;
  END IF;

  -- Optional diploma templates (table may not exist yet during 0022; exists from 0024+)
  IF to_regclass('public.challenge_diplomas') IS NOT NULL THEN
    SELECT max(headline) FILTER (WHERE lang = 'cs'),
           max(headline) FILTER (WHERE lang = 'en'),
           max(headline) FILTER (WHERE lang = 'de'),
           max(body) FILTER (WHERE lang = 'cs'),
           max(body) FILTER (WHERE lang = 'en'),
           max(body) FILTER (WHERE lang = 'de')
      INTO v_headline_cs, v_headline_en, v_headline_de, v_body_cs, v_body_en, v_body_de
      FROM public.challenge_diplomas
     WHERE challenge_id = p_challenge_id AND user_id IS NULL AND status = 'published'
       AND now() <@ tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)');
  END IF;

  INSERT INTO public.challenge_i18n (challenge_id, locale, title, description, diploma_headline, diploma_body)
  SELECT p_challenge_id, x.locale, x.title, coalesce(x.description, ''), x.headline, x.body
  FROM (VALUES
    ('cs', t.title_cs, d.desc_cs, v_headline_cs, v_body_cs),
    ('en', t.title_en, d.desc_en, v_headline_en, v_body_en),
    ('de', t.title_de, d.desc_de, v_headline_de, v_body_de)
  ) AS x (locale, title, description, headline, body)
  WHERE nullif(btrim(x.title), '') IS NOT NULL
  ON CONFLICT (challenge_id, locale) DO UPDATE
    SET title = excluded.title, description = excluded.description,
        diploma_headline = excluded.diploma_headline, diploma_body = excluded.diploma_body;

  DELETE FROM public.challenge_i18n i
   WHERE i.challenge_id = p_challenge_id
     AND ((i.locale = 'en' AND nullif(btrim(t.title_en), '') IS NULL)
       OR (i.locale = 'de' AND nullif(btrim(t.title_de), '') IS NULL));

  PERFORM set_config('viateria.legacy_sync', 'off', true);
END;
$$;
REVOKE ALL ON FUNCTION private.refresh_legacy_challenge_i18n(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.trg_refresh_legacy_challenge_i18n()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM private.refresh_legacy_challenge_i18n(coalesce(NEW.challenge_id, OLD.challenge_id));
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION private.trg_refresh_legacy_challenge_i18n() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS challenge_titles_legacy_sync ON public.challenge_titles;
CREATE TRIGGER challenge_titles_legacy_sync
  AFTER INSERT OR UPDATE OR DELETE ON public.challenge_titles
  FOR EACH ROW EXECUTE FUNCTION private.trg_refresh_legacy_challenge_i18n();
DROP TRIGGER IF EXISTS challenge_descriptions_legacy_sync ON public.challenge_descriptions;
CREATE TRIGGER challenge_descriptions_legacy_sync
  AFTER INSERT OR UPDATE OR DELETE ON public.challenge_descriptions
  FOR EACH ROW EXECUTE FUNCTION private.trg_refresh_legacy_challenge_i18n();

CREATE OR REPLACE FUNCTION private.refresh_legacy_challenge_prices(p_challenge_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  p public.challenge_prices%ROWTYPE;
BEGIN
  SELECT * INTO p FROM public.challenge_prices
   WHERE challenge_id = p_challenge_id AND status = 'published'
     AND now() <@ tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)')
   LIMIT 1;
  IF p.id IS NULL THEN
    RETURN;
  END IF;
  PERFORM set_config('viateria.legacy_sync', 'on', true);
  UPDATE public.challenges
     SET diploma_price_cents = p.diploma_price_cents,
         medal_price_cents = p.medal_price_cents,
         currency = p.currency,
         updated_at = now()
   WHERE id = p_challenge_id
     AND (diploma_price_cents, medal_price_cents, currency)
         IS DISTINCT FROM (p.diploma_price_cents, p.medal_price_cents, p.currency);
  PERFORM set_config('viateria.legacy_sync', 'off', true);
END;
$$;
REVOKE ALL ON FUNCTION private.refresh_legacy_challenge_prices(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.trg_refresh_legacy_challenge_prices()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM private.refresh_legacy_challenge_prices(coalesce(NEW.challenge_id, OLD.challenge_id));
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION private.trg_refresh_legacy_challenge_prices() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS challenge_prices_legacy_sync ON public.challenge_prices;
CREATE TRIGGER challenge_prices_legacy_sync
  AFTER INSERT OR UPDATE OR DELETE ON public.challenge_prices
  FOR EACH ROW EXECUTE FUNCTION private.trg_refresh_legacy_challenge_prices();

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
  END LOOP;
END;
$$;
REVOKE ALL ON FUNCTION private.refresh_all_legacy_challenge_copies() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.refresh_all_legacy_challenge_copies() TO service_role;

CREATE OR REPLACE FUNCTION private.guard_legacy_challenge_i18n()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  IF current_setting('viateria.legacy_sync', true) = 'on' THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP = 'DELETE'
     AND NOT EXISTS (SELECT 1 FROM public.challenges c WHERE c.id = OLD.challenge_id) THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'challenge_i18n is a read-only legacy copy since 0022 – edit challenge_titles / challenge_descriptions / challenge_diplomas templates'
    USING ERRCODE = 'read_only_sql_transaction';
END;
$$;
DROP TRIGGER IF EXISTS challenge_i18n_guard ON public.challenge_i18n;
CREATE TRIGGER challenge_i18n_guard
  BEFORE INSERT OR UPDATE OR DELETE ON public.challenge_i18n
  FOR EACH ROW EXECUTE FUNCTION private.guard_legacy_challenge_i18n();

CREATE OR REPLACE FUNCTION private.guard_legacy_challenge_prices()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  IF current_setting('viateria.legacy_sync', true) = 'on' THEN
    RETURN NEW;
  END IF;
  IF (NEW.diploma_price_cents, NEW.medal_price_cents, NEW.currency)
     IS DISTINCT FROM (OLD.diploma_price_cents, OLD.medal_price_cents, OLD.currency)
     AND EXISTS (SELECT 1 FROM public.challenge_prices p WHERE p.challenge_id = NEW.id) THEN
    RAISE EXCEPTION 'challenges.*_price_cents/currency are legacy copies since 0022 – edit challenge_prices'
      USING ERRCODE = 'read_only_sql_transaction';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS challenges_price_guard ON public.challenges;
CREATE TRIGGER challenges_price_guard
  BEFORE UPDATE OF diploma_price_cents, medal_price_cents, currency ON public.challenges
  FOR EACH ROW EXECUTE FUNCTION private.guard_legacy_challenge_prices();

-- =============================================================================
-- ROLLBACK (manual)
-- =============================================================================
-- DROP TRIGGER IF EXISTS challenges_price_guard ON public.challenges;
-- DROP TRIGGER IF EXISTS challenge_i18n_guard ON public.challenge_i18n;
-- DROP TRIGGER IF EXISTS challenge_prices_legacy_sync ON public.challenge_prices;
-- DROP TRIGGER IF EXISTS challenge_descriptions_legacy_sync ON public.challenge_descriptions;
-- DROP TRIGGER IF EXISTS challenge_titles_legacy_sync ON public.challenge_titles;
-- DROP FUNCTION IF EXISTS private.guard_legacy_challenge_prices(), private.guard_legacy_challenge_i18n(),
--   private.refresh_all_legacy_challenge_copies(), private.trg_refresh_legacy_challenge_prices(),
--   private.refresh_legacy_challenge_prices(uuid), private.trg_refresh_legacy_challenge_i18n(),
--   private.refresh_legacy_challenge_i18n(uuid);
-- TRUNCATE public.challenge_prices, public.challenge_descriptions, public.challenge_titles;
-- =============================================================================
