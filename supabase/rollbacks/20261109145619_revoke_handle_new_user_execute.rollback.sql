-- Undo 20261109145619_revoke_handle_new_user_execute.sql
-- Own transaction, so psql -f does not need --single-transaction.
-- A refused guard must be a non-zero exit. psql exits 0 on a SQL error
-- unless ON_ERROR_STOP is set:
--   psql -v ON_ERROR_STOP=1 -f supabase/rollbacks/20261109145619_revoke_handle_new_user_execute.rollback.sql
-- Apply only after opting in, same session:
--   psql -v ON_ERROR_STOP=1 -c "SELECT set_config('viateria.allow_rollback','on',false)" -f supabase/rollbacks/20261109145619_revoke_handle_new_user_execute.rollback.sql

BEGIN;

DO $$
BEGIN
  IF coalesce(current_setting('viateria.allow_rollback', true), '') IS DISTINCT FROM 'on' THEN
    RAISE EXCEPTION 'rollback refused: psql -v ON_ERROR_STOP=1 -f this file exits non-zero until SELECT set_config(''viateria.allow_rollback'', ''on'', false)';
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION public.handle_new_user() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO anon;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;

COMMIT;
