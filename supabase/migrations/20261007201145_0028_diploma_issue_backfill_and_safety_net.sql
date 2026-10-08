-- 0028_diploma_issue_backfill_and_safety_net.sql
-- APPLIED to prod yzmbxxgesnbsqygzgdky 2026-10-07 22:11 Prague as migration 20261007201145 diploma_issue_backfill_and_safety_net (approved by Ondřej).
--
-- Root cause: diploma_status() returns 'locked' when there is no issued
-- challenge_diplomas row (user_id NOT NULL). Rows are only issued by
-- verify_waypoint (0025) at the moment the last waypoint is verified.
-- Completions that happened BEFORE 0025 (e.g. toulky-vysocinou, completed
-- 2026-10-07 17:37 UTC, 0025 applied 17:48 UTC) were backfilled into
-- challenge_participations (status=completed) by 0024/0025, but nobody called
-- private.issue_challenge_diploma for them -> state 'locked' -> Flutter
-- DiplomaPhase.incomplete ("The diploma opens after you finish the challenge.").
--
-- Fix:
--  1) backfill: issue diplomas for every completed participation without one
--  2) safety net: AFTER trigger on challenge_participations issues the diploma
--     whenever a row becomes 'completed' (any write path, incl. future backfills)
--  3) self-heal: diploma_status() lazily issues when participation is completed
--     but the row is missing (function becomes VOLATILE; rpc() uses POST anyway)
-- Idempotent: issue_challenge_diploma returns the existing id if present.

BEGIN;

-- 2) trigger -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.trg_issue_diploma_on_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.status = 'completed'
     AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'completed') THEN
    BEGIN
      PERFORM private.issue_challenge_diploma(NEW.user_id, NEW.challenge_id);
    EXCEPTION WHEN others THEN
      RAISE WARNING 'issue diploma on completion failed for % / %: %',
        NEW.user_id, NEW.challenge_id, SQLERRM;
    END;
  END IF;
  RETURN NULL;
END;
$function$;
REVOKE ALL ON FUNCTION private.trg_issue_diploma_on_completion() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS challenge_participations_issue_diploma ON public.challenge_participations;
CREATE TRIGGER challenge_participations_issue_diploma
  AFTER INSERT OR UPDATE OF status ON public.challenge_participations
  FOR EACH ROW EXECUTE FUNCTION private.trg_issue_diploma_on_completion();

-- 3) self-healing diploma_status (same body as 0026 + lazy issue) -----------
CREATE OR REPLACE FUNCTION public.diploma_status(p_challenge_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE SECURITY DEFINER
SET search_path TO ''
AS $function$
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
  IF d.id IS NULL AND EXISTS (
       SELECT 1 FROM public.challenge_participations cp
        WHERE cp.user_id = v_uid AND cp.challenge_id = p_challenge_id
          AND cp.status = 'completed') THEN
    BEGIN
      PERFORM private.issue_challenge_diploma(v_uid, p_challenge_id);
    EXCEPTION WHEN others THEN
      RAISE WARNING 'diploma_status: lazy issue failed for % / %: %', v_uid, p_challenge_id, SQLERRM;
    END;
    SELECT * INTO d FROM public.challenge_diplomas
     WHERE challenge_id = p_challenge_id AND user_id = v_uid;
  END IF;
  IF d.completed_at IS NOT NULL THEN
    v_day := to_char((d.completed_at AT TIME ZONE 'Europe/Prague')::date, 'DD.MM.YYYY');
  END IF;
  v_state := CASE
    WHEN d.id IS NULL THEN 'locked'
    WHEN d.revoked_at IS NOT NULL THEN 'revoked'
    WHEN NOT private.diploma_entitled(v_uid, p_challenge_id) THEN 'buy'
    WHEN d.recipient_name_display IS NULL THEN 'need_name'
    WHEN d.image_path IS NULL THEN 'render'
    ELSE 'ready' END;
  RETURN jsonb_build_object(
    'state', v_state,
    'diploma_id', d.id,
    'lang', d.lang,
    'recipient_name_display', d.recipient_name_display,
    'completion_day_label', CASE WHEN v_day IS NULL THEN NULL
                                 ELSE 'dokončeno dne ' || v_day END,
    'completed_on', (d.completed_at AT TIME ZONE 'Europe/Prague')::date,
    'rendered_at', d.rendered_at);
END;
$function$;
REVOKE ALL ON FUNCTION public.diploma_status(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.diploma_status(uuid) TO authenticated;

-- 1) backfill ----------------------------------------------------------------
DO $$
DECLARE r record; n int := 0;
BEGIN
  FOR r IN
    SELECT cp.user_id, cp.challenge_id
      FROM public.challenge_participations cp
     WHERE cp.status = 'completed'
       AND NOT EXISTS (SELECT 1 FROM public.challenge_diplomas d
                        WHERE d.challenge_id = cp.challenge_id AND d.user_id = cp.user_id)
  LOOP
    BEGIN
      PERFORM private.issue_challenge_diploma(r.user_id, r.challenge_id);
      n := n + 1;
    EXCEPTION WHEN others THEN
      RAISE WARNING 'backfill issue failed for % / %: %', r.user_id, r.challenge_id, SQLERRM;
    END;
  END LOOP;
  RAISE NOTICE '0028 backfill issued % diploma(s)', n;
END $$;

COMMIT;

-- Verify (expect 1 row for onhalu / toulky-vysocinou, image_path NULL -> state 'render'):
-- SELECT user_id, challenge_id, lang, recipient_name_display, completed_at, image_path
--   FROM public.challenge_diplomas WHERE user_id IS NOT NULL;

-- Rollback:
-- DROP TRIGGER IF EXISTS challenge_participations_issue_diploma ON public.challenge_participations;
-- DROP FUNCTION IF EXISTS private.trg_issue_diploma_on_completion();
-- re-run 0026 section 5 (diploma_status STABLE without lazy issue).
-- Issued rows can stay (they are what verify_waypoint would have created).
