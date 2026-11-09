-- Revoke client EXECUTE on public.handle_new_user.
--
-- The function is SECURITY DEFINER and only exists so the
-- on_auth_user_created trigger can insert public.profiles. anon and
-- authenticated must not call it. PUBLIC holds Postgres' default EXECUTE
-- grant, so it is revoked too.
--
-- The trigger keeps working. Postgres checks EXECUTE when the trigger is
-- created, not each time it fires, and the function still runs as its owner.
-- supabase_auth_admin (the role Supabase Auth uses to insert auth.users)
-- receives EXECUTE when that role exists, so recreating the trigger still
-- succeeds.
--
-- Rollback: supabase/rollbacks/20261109145619_revoke_handle_new_user_execute.rollback.sql
-- NOT APPLIED on prod by this change. Apply only after Ondřej's explicit OK.

DO $$
BEGIN
  IF to_regprocedure('public.handle_new_user()') IS NULL THEN
    RAISE EXCEPTION 'public.handle_new_user() is missing';
  END IF;
END $$;

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;
  END IF;
END $$;
