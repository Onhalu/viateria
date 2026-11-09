-- Undo 20261109145619_revoke_handle_new_user_execute.sql
-- Own transaction, so psql -f does not need --single-transaction.
-- Refuses to run until the operator opts in:
--   psql -v ON_ERROR_STOP=1 -c "SELECT set_config('viateria.allow_rollback','on',false)" -f thisfile

BEGIN;

DO $$
BEGIN
  IF coalesce(current_setting('viateria.allow_rollback', true), '') IS DISTINCT FROM 'on' THEN
    RAISE EXCEPTION 'rollback refused: SELECT set_config(''viateria.allow_rollback'', ''on'', false) before this file';
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION public.handle_new_user() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO anon;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;

COMMIT;
