-- challenge_waypoint_photos was SECURITY DEFINER (security_invoker = false)
-- so the gallery could read other hikers' photos despite own-row RLS on
-- waypoint_progress. That bypass is the advisor ERROR.
--
-- The view now runs as the caller (security_invoker). A second SELECT
-- policy exposes only the rows the gallery already showed: a real photo
-- path on a challenge private.challenge_readable says the caller may see.
-- GPS sentinel paths stay on the own-row policy. The view still omits
-- user_id, and that column is revoked from anon and authenticated so the
-- new policy does not add it to the Data API. The photo path already
-- contains the owner folder the app signs.
--
-- NOT APPLIED on prod by this change. Apply only after Ondřej's explicit OK.

DO $$
BEGIN
  IF to_regclass('public.challenge_waypoint_photos') IS NULL THEN
    RAISE EXCEPTION 'public.challenge_waypoint_photos is missing';
  END IF;
  IF to_regprocedure('private.challenge_readable(uuid)') IS NULL THEN
    RAISE EXCEPTION 'private.challenge_readable(uuid) is missing';
  END IF;
END $$;

DROP POLICY IF EXISTS "shared verification photos readable"
  ON public.waypoint_progress;

CREATE POLICY "shared verification photos readable"
  ON public.waypoint_progress
  FOR SELECT
  TO authenticated
  USING (
    photo_path IS NOT NULL
    AND length(btrim(photo_path)) > 0
    AND photo_path NOT LIKE '%/gps/%'
    AND EXISTS (
      SELECT 1
      FROM public.waypoints AS w
      WHERE w.id = waypoint_id
        AND private.challenge_readable(w.challenge_id)
    )
  );

CREATE OR REPLACE VIEW public.challenge_waypoint_photos
WITH (security_invoker = true, security_barrier = true) AS
SELECT
  w.challenge_id,
  p.waypoint_id,
  p.photo_path,
  p.completed_at
FROM public.waypoint_progress AS p
JOIN public.waypoints AS w ON w.id = p.waypoint_id
JOIN public.challenges AS c ON c.id = w.challenge_id
WHERE c.status = 'published'
  AND (
    c.is_promo = false
    OR private.user_has_promo_challenge(c.id)
  )
  AND p.photo_path IS NOT NULL
  AND length(btrim(p.photo_path)) > 0
  AND p.photo_path NOT LIKE '%/gps/%';

ALTER VIEW public.challenge_waypoint_photos
  SET (security_invoker = true, security_barrier = true);

COMMENT ON VIEW public.challenge_waypoint_photos IS
  'Verification photos for challenges the caller can read. Omits user_id and GPS sentinel paths. security_invoker: waypoint_progress RLS (own row, plus shared non-GPS photos) applies to the caller.';

REVOKE ALL ON TABLE public.challenge_waypoint_photos FROM PUBLIC;
REVOKE ALL ON TABLE public.challenge_waypoint_photos FROM anon;
GRANT SELECT ON TABLE public.challenge_waypoint_photos TO authenticated;

-- Table-level SELECT would still expose user_id on the new shared rows.
-- Re-grant every column except user_id. service_role and the owner are
-- untouched, so security-definer verify and storage checks still see it.
DO $$
DECLARE
  cols text;
BEGIN
  SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position)
    INTO cols
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'waypoint_progress'
    AND column_name <> 'user_id';
  IF cols IS NULL THEN
    RAISE EXCEPTION 'waypoint_progress has no columns besides user_id';
  END IF;
  EXECUTE 'REVOKE SELECT ON TABLE public.waypoint_progress FROM anon, authenticated';
  EXECUTE format(
    'GRANT SELECT (%s) ON TABLE public.waypoint_progress TO authenticated',
    cols
  );
END $$;

-- =============================================================================
-- ROLLBACK (manual; do not run as part of this migration)
-- =============================================================================
-- DROP POLICY IF EXISTS "shared verification photos readable" ON public.waypoint_progress;
-- GRANT SELECT ON TABLE public.waypoint_progress TO anon, authenticated;
-- CREATE OR REPLACE VIEW public.challenge_waypoint_photos
-- WITH (security_invoker = false, security_barrier = true) AS
-- SELECT w.challenge_id, p.waypoint_id, p.photo_path, p.completed_at
-- FROM public.waypoint_progress p
-- JOIN public.waypoints w ON w.id = p.waypoint_id
-- JOIN public.challenges c ON c.id = w.challenge_id
-- WHERE c.status = 'published'
--   AND (c.is_promo = false OR private.user_has_promo_challenge(c.id))
--   AND p.photo_path IS NOT NULL
--   AND length(btrim(p.photo_path)) > 0
--   AND p.photo_path NOT LIKE '%/gps/%';
-- ALTER VIEW public.challenge_waypoint_photos
--   SET (security_invoker = false, security_barrier = true);
-- COMMENT ON VIEW public.challenge_waypoint_photos IS
--   'Verification photos for published challenge waypoints, all users. Omits user_id and GPS sentinel paths. security_invoker is off so own-row waypoint_progress RLS does not hide other people.';
-- REVOKE ALL ON TABLE public.challenge_waypoint_photos FROM PUBLIC, anon, authenticated;
-- GRANT SELECT ON TABLE public.challenge_waypoint_photos TO authenticated;
-- =============================================================================
