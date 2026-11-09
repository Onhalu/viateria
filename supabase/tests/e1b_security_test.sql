BEGIN;
SELECT plan(15);

SELECT ok(
  NOT has_function_privilege('anon', 'public.handle_new_user()', 'EXECUTE'),
  'anon cannot EXECUTE handle_new_user'
);

SELECT ok(
  NOT has_function_privilege(
    'authenticated',
    'public.handle_new_user()',
    'EXECUTE'
  ),
  'authenticated cannot EXECUTE handle_new_user'
);

SELECT ok(
  NOT has_function_privilege('public', 'public.handle_new_user()', 'EXECUTE'),
  'public cannot EXECUTE handle_new_user'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_trigger AS t
    JOIN pg_class AS c ON c.oid = t.tgrelid
    JOIN pg_namespace AS n ON n.oid = c.relnamespace
    JOIN pg_proc AS p ON p.oid = t.tgfoid
    WHERE n.nspname = 'auth'
      AND c.relname = 'users'
      AND t.tgname = 'on_auth_user_created'
      AND NOT t.tgisinternal
      AND p.proname = 'handle_new_user'
  ),
  'signup trigger still calls handle_new_user'
);

SELECT ok(
  NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin')
  OR has_function_privilege(
    'supabase_auth_admin',
    'public.handle_new_user()',
    'EXECUTE'
  ),
  'supabase_auth_admin can EXECUTE handle_new_user when the role exists'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_class AS c
    JOIN pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'challenge_waypoint_photos'
      AND c.relkind = 'v'
      AND c.reloptions @> ARRAY['security_invoker=true']
      AND c.reloptions @> ARRAY['security_barrier=true']
  ),
  'challenge_waypoint_photos is security_invoker'
);

-- _seed_challenge is a prod helper. A database built only from repo
-- migrations does not have it, and the lock migration skips. Tests 7–11
-- skip in that case so the rest of the file still runs.
SELECT CASE
  WHEN to_regprocedure('public._seed_challenge(text,text,text,text,text,integer,integer,integer,text,text,timestamp with time zone,jsonb)') IS NULL
  THEN skip(
    '_seed_challenge is not created by repo migrations; search_path lock applies only where the helper already exists',
    1
  )
  ELSE ok(
    EXISTS (
      SELECT 1
      FROM pg_proc AS p
      JOIN pg_namespace AS n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.proname = '_seed_challenge'
        AND EXISTS (
          SELECT 1
          FROM unnest(coalesce(p.proconfig, ARRAY[]::text[])) AS cfg
          WHERE cfg IN ('search_path=', 'search_path=""')
        )
    ),
    '_seed_challenge search_path is empty'
  )
END;

SELECT CASE
  WHEN to_regprocedure('public._seed_challenge(text,text,text,text,text,integer,integer,integer,text,text,timestamp with time zone,jsonb)') IS NULL
  THEN skip(
    '_seed_challenge is not created by repo migrations; anon EXECUTE is not granted because the helper is absent',
    1
  )
  ELSE ok(
    NOT has_function_privilege(
      'anon',
      'public._seed_challenge(text,text,text,text,text,integer,integer,integer,text,text,timestamp with time zone,jsonb)',
      'EXECUTE'
    ),
    'anon cannot EXECUTE _seed_challenge'
  )
END;

SELECT CASE
  WHEN to_regprocedure('public._seed_challenge(text,text,text,text,text,integer,integer,integer,text,text,timestamp with time zone,jsonb)') IS NULL
  THEN skip(
    '_seed_challenge is not created by repo migrations; authenticated EXECUTE is not granted because the helper is absent',
    1
  )
  ELSE ok(
    NOT has_function_privilege(
      'authenticated',
      'public._seed_challenge(text,text,text,text,text,integer,integer,integer,text,text,timestamp with time zone,jsonb)',
      'EXECUTE'
    ),
    'authenticated cannot EXECUTE _seed_challenge'
  )
END;

SELECT CASE
  WHEN to_regprocedure('public._seed_challenge(text,text,text,text,text,integer,integer,integer,text,text,timestamp with time zone,jsonb)') IS NULL
  THEN skip(
    '_seed_challenge is not created by repo migrations; PUBLIC EXECUTE is not granted because the helper is absent',
    1
  )
  ELSE ok(
    NOT has_function_privilege(
      'public',
      'public._seed_challenge(text,text,text,text,text,integer,integer,integer,text,text,timestamp with time zone,jsonb)',
      'EXECUTE'
    ),
    'public cannot EXECUTE _seed_challenge'
  )
END;

CREATE TEMP TABLE seed_call (sqlstate text, message text);

DO $$
BEGIN
  IF to_regprocedure('public._seed_challenge(text,text,text,text,text,integer,integer,integer,text,text,timestamp with time zone,jsonb)') IS NULL THEN
    RETURN;
  END IF;
  BEGIN
    PERFORM public._seed_challenge(
      'e1b-seed-call',
      'Seed call',
      'notes',
      'region',
      'free',
      0,
      0,
      0,
      'draft',
      'active',
      now(),
      '[]'::jsonb
    );
    INSERT INTO seed_call VALUES ('00000', 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO seed_call VALUES (SQLSTATE, SQLERRM);
  END;
END $$;

SELECT CASE
  WHEN to_regprocedure('public._seed_challenge(text,text,text,text,text,integer,integer,integer,text,text,timestamp with time zone,jsonb)') IS NULL
  THEN skip(
    '_seed_challenge is not created by repo migrations; postgres call is skipped because the helper is absent',
    1
  )
  ELSE ok(
    (SELECT sqlstate FROM seed_call) NOT IN ('42883', '42501'),
    'postgres can call _seed_challenge and the body resolves (not undefined-function)'
  )
END;

-- Gallery still readable for a signed-in caller after security_invoker.
-- Insert only auth.users columns this database actually has. GoTrue's
-- column set differs between the base image and a fully migrated local stack.
DO $users$
DECLARE
  ids uuid[] := ARRAY[
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  ];
  emails text[] := ARRAY['ada@example.com', 'bea@example.com'];
  names text[] := ARRAY['Ada', 'Bea'];
  known text[] := ARRAY[
    'instance_id', 'id', 'aud', 'role', 'email', 'encrypted_password',
    'email_confirmed_at', 'confirmed_at', 'raw_app_meta_data',
    'raw_user_meta_data', 'created_at', 'updated_at', 'confirmation_token',
    'recovery_token', 'email_change_token_new', 'email_change',
    'email_change_token_current', 'phone_change', 'phone_change_token',
    'reauthentication_token', 'is_sso_user', 'is_anonymous'
  ];
  present text[] := ARRAY[]::text[];
  col text;
  i integer;
  sql text;
  col_sql text;
  values_sql text;
BEGIN
  FOREACH col IN ARRAY known LOOP
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'auth'
        AND table_name = 'users'
        AND column_name = col
        AND is_generated = 'NEVER'
    ) THEN
      present := present || col;
    END IF;
  END LOOP;

  FOR i IN 1..2 LOOP
    col_sql := '';
    values_sql := '';
    FOREACH col IN ARRAY present LOOP
      IF col_sql <> '' THEN
        col_sql := col_sql || ', ';
        values_sql := values_sql || ', ';
      END IF;
      col_sql := col_sql || quote_ident(col);
      values_sql := values_sql || CASE col
        WHEN 'instance_id' THEN quote_literal('00000000-0000-0000-0000-000000000000') || '::uuid'
        WHEN 'id' THEN quote_literal(ids[i]::text) || '::uuid'
        WHEN 'aud' THEN quote_literal('authenticated')
        WHEN 'role' THEN quote_literal('authenticated')
        WHEN 'email' THEN quote_literal(emails[i])
        WHEN 'encrypted_password' THEN quote_literal('')
        WHEN 'email_confirmed_at' THEN 'now()'
        WHEN 'confirmed_at' THEN 'now()'
        WHEN 'raw_app_meta_data' THEN quote_literal('{"provider":"email","providers":["email"]}') || '::jsonb'
        WHEN 'raw_user_meta_data' THEN quote_literal(json_build_object('display_name', names[i])::text) || '::jsonb'
        WHEN 'created_at' THEN 'now()'
        WHEN 'updated_at' THEN 'now()'
        WHEN 'is_sso_user' THEN 'false'
        WHEN 'is_anonymous' THEN 'false'
        ELSE quote_literal('')
      END;
    END LOOP;
    sql := format('INSERT INTO auth.users (%s) VALUES (%s)', col_sql, values_sql);
    EXECUTE sql;
  END LOOP;
END
$users$;

SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
      AND display_name = 'Ada'
  ),
  'handle_new_user still inserts the profile'
);

INSERT INTO public.places (id, name, category, lat, lng)
VALUES
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'Photo place', 'historical', 49.2, 16.6),
  ('c1c1c1c1-c1c1-4c1c-8c1c-c1c1c1c1c1c1', 'GPS place', 'nature', 49.3, 16.7);

INSERT INTO public.challenges (
  id, slug, access_mode, pricing_type, price_cents, status, is_promo
) VALUES (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'e1b-gallery',
  'open',
  'free',
  0,
  'published',
  false
);

INSERT INTO public.waypoints (
  id, challenge_id, sort_order, lat, lng, place_id
) VALUES
  (
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    1, 49.2, 16.6,
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ),
  (
    'e1e1e1e1-e1e1-4e1e-8e1e-e1e1e1e1e1e1',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    2, 49.3, 16.7,
    'c1c1c1c1-c1c1-4c1c-8c1c-c1c1c1c1c1c1'
  );

INSERT INTO public.waypoint_progress (user_id, waypoint_id, photo_path)
VALUES (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/e1b/photo.jpg'
), (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'e1e1e1e1-e1e1-4e1e-8e1e-e1e1e1e1e1e1',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/gps/e1b/sentinel'
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}',
  true
);
SELECT set_config(
  'request.jwt.claim.sub',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  true
);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SET ROLE authenticated;

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.waypoint_progress
    WHERE user_id = auth.uid()
  ),
  2,
  'owner can select own waypoint_progress filtered by user_id'
);

RESET ROLE;

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}',
  true
);
SELECT set_config(
  'request.jwt.claim.sub',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  true
);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SET ROLE authenticated;

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.challenge_waypoint_photos
    WHERE challenge_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
      AND photo_path = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/e1b/photo.jpg'
  ),
  1,
  'another signed-in user can read the shared verification photo'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.challenge_waypoint_photos
    WHERE photo_path LIKE '%/gps/%'
  ),
  0,
  'GPS sentinel paths stay out of the gallery'
);

RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
