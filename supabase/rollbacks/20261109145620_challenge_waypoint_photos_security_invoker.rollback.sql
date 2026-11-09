-- Undo 20261109145620_challenge_waypoint_photos_security_invoker.sql
-- Own transaction, so psql -f does not need --single-transaction.
--   psql -v ON_ERROR_STOP=1 -c "SELECT set_config('viateria.allow_rollback','on',false)" -f thisfile

BEGIN;

DO $$
BEGIN
  IF coalesce(current_setting('viateria.allow_rollback', true), '') IS DISTINCT FROM 'on' THEN
    RAISE EXCEPTION 'rollback refused: SELECT set_config(''viateria.allow_rollback'', ''on'', false) before this file';
  END IF;
END $$;

DROP POLICY IF EXISTS "shared verification photos readable" ON public.waypoint_progress;

CREATE OR REPLACE VIEW public.challenge_waypoint_photos
WITH (security_invoker = false, security_barrier = true) AS
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
  SET (security_invoker = false, security_barrier = true);

COMMENT ON VIEW public.challenge_waypoint_photos IS
  'Verification photos for published challenge waypoints, all users. Omits user_id and GPS sentinel paths. security_invoker is off so own-row waypoint_progress RLS does not hide other people.';

REVOKE ALL ON TABLE public.challenge_waypoint_photos FROM PUBLIC;
REVOKE ALL ON TABLE public.challenge_waypoint_photos FROM anon;
GRANT SELECT ON TABLE public.challenge_waypoint_photos TO authenticated;

COMMIT;
