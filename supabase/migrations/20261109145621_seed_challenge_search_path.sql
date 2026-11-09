-- public._seed_challenge is a prod seed helper (it is not created by earlier
-- repo migrations) with a role-mutable search_path. Lock it to empty and
-- schema-qualify every reference the body needs.
--
-- The body matches the function installed on prod, except search_path and
-- pg_catalog qualification of now(), coalesce(), and jsonb_array_elements().
-- Tables were already public-qualified. place_id handling is unchanged.
-- EXECUTE is revoked from PUBLIC, anon, and authenticated on both paths.
-- postgres and service_role keep EXECUTE so the SQL editor can still seed.
--
-- A database built only from this repo does not have challenges.notes,
-- challenges.period_state, challenges.starts_at, or public.challenge_changes
-- (see 0016). Those databases get the same signature with search_path locked
-- and a body that refuses to run, so the helper cannot come back with a
-- mutable search_path. Prod has the columns, so prod gets the real body.
--
-- NOT APPLIED on prod by this change. Apply only after Ondřej's explicit OK.

DO $migration$
DECLARE
  deps_ok boolean;
BEGIN
  SELECT
    to_regclass('public.challenge_changes') IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'challenges'
        AND column_name = 'notes'
    )
    AND EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'challenges'
        AND column_name = 'period_state'
    )
    AND EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'challenges'
        AND column_name = 'starts_at'
    )
  INTO deps_ok;

  IF deps_ok THEN
    EXECUTE $fn$
      CREATE OR REPLACE FUNCTION public._seed_challenge(
        p_slug text,
        p_title text,
        p_notes text,
        p_region text,
        p_pricing text,
        p_price_cents integer,
        p_diploma integer,
        p_medal integer,
        p_status text,
        p_period text,
        p_ends timestamp with time zone,
        p_points jsonb
      )
      RETURNS uuid
      LANGUAGE plpgsql
      SET search_path = ''
      AS $body$
      DECLARE
        cid uuid;
        pt jsonb;
        i integer := 0;
        wid uuid;
      BEGIN
        INSERT INTO public.challenges (
          slug, access_mode, pricing_type, price_cents, currency, status,
          region, starts_at, ends_at, diploma_price_cents, medal_price_cents,
          period_state, notes
        ) VALUES (
          p_slug, 'open', p_pricing, p_price_cents, 'czk', p_status,
          p_region, NULL, p_ends, p_diploma, p_medal,
          p_period, p_notes
        )
        ON CONFLICT (slug) DO UPDATE SET
          pricing_type = excluded.pricing_type,
          price_cents = excluded.price_cents,
          status = excluded.status,
          region = excluded.region,
          ends_at = excluded.ends_at,
          diploma_price_cents = excluded.diploma_price_cents,
          medal_price_cents = excluded.medal_price_cents,
          period_state = excluded.period_state,
          notes = excluded.notes,
          updated_at = pg_catalog.now()
        RETURNING id INTO cid;

        INSERT INTO public.challenge_i18n (challenge_id, locale, title, description)
        VALUES (cid, 'cs', p_title, p_notes)
        ON CONFLICT (challenge_id, locale) DO UPDATE
          SET title = excluded.title, description = excluded.description;

        DELETE FROM public.waypoints WHERE challenge_id = cid;

        FOR pt IN SELECT * FROM pg_catalog.jsonb_array_elements(p_points)
        LOOP
          i := i + 1;
          INSERT INTO public.waypoints (challenge_id, sort_order, lat, lng, elevation_m)
          VALUES (
            cid,
            i,
            (pt->>'lat')::double precision,
            (pt->>'lng')::double precision,
            pg_catalog.coalesce((pt->>'elevation_m')::double precision, 0)
          )
          RETURNING id INTO wid;
          INSERT INTO public.waypoint_i18n (waypoint_id, locale, title, description)
          VALUES (wid, 'cs', pt->>'title', '');
        END LOOP;

        INSERT INTO public.challenge_changes (challenge_id, kind, summary)
        VALUES
          (cid, 'created', 'Testovací záznam ze zdrojového webu. Slug ' || p_slug || '.'),
          (
            cid,
            CASE WHEN p_status = 'published' THEN 'published' ELSE 'ended' END,
            CASE
              WHEN p_period = 'active' THEN 'Aktivní v katalogu.'
              ELSE 'Ukončená výzva, mimo katalog.'
            END
          );

        RETURN cid;
      END;
      $body$
    $fn$;

    REVOKE EXECUTE ON FUNCTION public._seed_challenge(
      text, text, text, text, text, integer, integer, integer, text, text,
      timestamp with time zone, jsonb
    ) FROM PUBLIC, anon, authenticated;
  ELSE
    EXECUTE $fn$
      CREATE OR REPLACE FUNCTION public._seed_challenge(
        p_slug text,
        p_title text,
        p_notes text,
        p_region text,
        p_pricing text,
        p_price_cents integer,
        p_diploma integer,
        p_medal integer,
        p_status text,
        p_period text,
        p_ends timestamp with time zone,
        p_points jsonb
      )
      RETURNS uuid
      LANGUAGE plpgsql
      SET search_path = ''
      AS $body$
      BEGIN
        RAISE EXCEPTION 'public._seed_challenge search_path is locked, but this database has no prod seed columns (notes, period_state, starts_at, challenge_changes)'
          USING ERRCODE = '42703';
      END;
      $body$
    $fn$;

    REVOKE ALL ON FUNCTION public._seed_challenge(
      text, text, text, text, text, integer, integer, integer, text, text,
      timestamp with time zone, jsonb
    ) FROM PUBLIC, anon, authenticated;
  END IF;
END
$migration$;

-- =============================================================================
-- ROLLBACK (manual; do not run as part of this migration)
-- =============================================================================
-- ALTER FUNCTION public._seed_challenge(
--   text, text, text, text, text, integer, integer, integer, text, text,
--   timestamp with time zone, jsonb
-- ) RESET search_path;
-- GRANT EXECUTE ON FUNCTION public._seed_challenge(
--   text, text, text, text, text, integer, integer, integer, text, text,
--   timestamp with time zone, jsonb
-- ) TO PUBLIC, anon, authenticated;
-- -- Qualified names stay valid after RESET. Drop the function only if this
-- -- migration created it on a database that did not already have the helper:
-- -- DROP FUNCTION IF EXISTS public._seed_challenge(
-- --   text, text, text, text, text, integer, integer, integer, text, text,
-- --   timestamp with time zone, jsonb
-- -- );
-- =============================================================================
