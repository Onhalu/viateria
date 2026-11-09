-- Undo 20261109145621_seed_challenge_search_path.sql
-- Own transaction, so psql -f does not need --single-transaction.
-- Does not rewrite the function body.
-- A refused guard must be a non-zero exit. psql exits 0 on a SQL error
-- unless ON_ERROR_STOP is set:
--   psql -v ON_ERROR_STOP=1 -f supabase/rollbacks/20261109145621_seed_challenge_search_path.rollback.sql
-- Apply only after opting in, same session:
--   psql -v ON_ERROR_STOP=1 -c "SELECT set_config('viateria.allow_rollback','on',false)" -f supabase/rollbacks/20261109145621_seed_challenge_search_path.rollback.sql

BEGIN;

DO $$
BEGIN
  IF coalesce(current_setting('viateria.allow_rollback', true), '') IS DISTINCT FROM 'on' THEN
    RAISE EXCEPTION 'rollback refused: psql -v ON_ERROR_STOP=1 -f this file exits non-zero until SELECT set_config(''viateria.allow_rollback'', ''on'', false)';
  END IF;
  IF to_regprocedure(
    'public._seed_challenge(text,text,text,text,text,integer,integer,integer,text,text,timestamp with time zone,jsonb)'
  ) IS NULL THEN
    RAISE EXCEPTION 'public._seed_challenge is absent; nothing to roll back';
  END IF;
END $$;

ALTER FUNCTION public._seed_challenge(
  text, text, text, text, text, integer, integer, integer, text, text,
  timestamp with time zone, jsonb
) RESET search_path;

GRANT EXECUTE ON FUNCTION public._seed_challenge(
  text, text, text, text, text, integer, integer, integer, text, text,
  timestamp with time zone, jsonb
) TO PUBLIC, anon, authenticated;

COMMIT;
