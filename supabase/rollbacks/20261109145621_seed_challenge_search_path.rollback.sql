-- Undo 20261109145621_seed_challenge_search_path.sql
-- Own transaction, so psql -f does not need --single-transaction.
-- Does not rewrite the function body.
--   psql -v ON_ERROR_STOP=1 -c "SELECT set_config('viateria.allow_rollback','on',false)" -f thisfile

BEGIN;

DO $$
BEGIN
  IF coalesce(current_setting('viateria.allow_rollback', true), '') IS DISTINCT FROM 'on' THEN
    RAISE EXCEPTION 'rollback refused: SELECT set_config(''viateria.allow_rollback'', ''on'', false) before this file';
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
