-- public._seed_challenge is a prod seed helper. Its tables are already
-- schema-qualified. now(), coalesce(), and jsonb_array_elements() live in
-- pg_catalog, which Postgres still searches when search_path is empty.
-- Do not rewrite the body: COALESCE is syntax, not pg_catalog.coalesce().
--
-- Lock the search path and revoke client EXECUTE. postgres and service_role
-- keep EXECUTE. A database that does not have the helper skips this file.
--
-- Rollback: supabase/rollbacks/20261109145621_seed_challenge_search_path.rollback.sql
-- NOT APPLIED on prod by this change. Apply only after Ondřej's explicit OK.

DO $migration$
BEGIN
  IF to_regprocedure(
    'public._seed_challenge(text,text,text,text,text,integer,integer,integer,text,text,timestamp with time zone,jsonb)'
  ) IS NULL THEN
    RAISE NOTICE 'public._seed_challenge is absent; search_path lock skipped';
    RETURN;
  END IF;

  EXECUTE $sql$
    ALTER FUNCTION public._seed_challenge(
      text, text, text, text, text, integer, integer, integer, text, text,
      timestamp with time zone, jsonb
    ) SET search_path = ''
  $sql$;

  EXECUTE $sql$
    REVOKE EXECUTE ON FUNCTION public._seed_challenge(
      text, text, text, text, text, integer, integer, integer, text, text,
      timestamp with time zone, jsonb
    ) FROM PUBLIC, anon, authenticated
  $sql$;
END
$migration$;
