-- VANDERY+ pgTAP. Fixtures DB-01…DB-16 (TEST plan §0–§1).
-- Runs inside the supabase test transaction. Does not touch a remote project.

begin;

create extension if not exists pgtap with schema extensions;

select plan(56);

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, email_change,
  email_change_token_new, recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000001',
    'authenticated', 'authenticated', 'u-none@vandery.test', '',
    now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000002',
    'authenticated', 'authenticated', 'u-active@vandery.test', '',
    now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000003',
    'authenticated', 'authenticated', 'u-soft@vandery.test', '',
    now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000004',
    'authenticated', 'authenticated', 'u-expired-time@vandery.test', '',
    now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000005',
    'authenticated', 'authenticated', 'u-expired-status@vandery.test', '',
    now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000006',
    'authenticated', 'authenticated', 'u-revoked@vandery.test', '',
    now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000007',
    'authenticated', 'authenticated', 'u-delete@vandery.test', '',
    now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  );

-- handle_new_user should have inserted profiles. Make sure they exist.
insert into public.profiles (id, display_name, locale)
values
  ('00000000-0000-4000-8000-000000000001', 'None', 'cs'),
  ('00000000-0000-4000-8000-000000000002', 'Active', 'cs'),
  ('00000000-0000-4000-8000-000000000003', 'Soft', 'cs'),
  ('00000000-0000-4000-8000-000000000004', 'ExpiredTime', 'cs'),
  ('00000000-0000-4000-8000-000000000005', 'ExpiredStatus', 'cs'),
  ('00000000-0000-4000-8000-000000000006', 'Revoked', 'cs'),
  ('00000000-0000-4000-8000-000000000007', 'Delete', 'cs')
on conflict (id) do nothing;

insert into public.vandery_plus_memberships (
  id, user_id, status, starts_at, expires_at, cancel_at_period_end,
  fapi_subscription_id, fapi_invoice_id, amount_cents, currency
)
values
  (
    '10000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000002',
    'active', now() - interval '1 day', now() + interval '20 days', false,
    'sub-active', 'inv-active', 59900, 'CZK'
  ),
  (
    '10000000-0000-4000-8000-000000000003',
    '00000000-0000-4000-8000-000000000003',
    'active', now() - interval '1 day', now() + interval '5 days', true,
    'sub-soft', 'inv-soft', 59900, 'CZK'
  ),
  (
    '10000000-0000-4000-8000-000000000004',
    '00000000-0000-4000-8000-000000000004',
    'active', now() - interval '40 days', now() - interval '1 minute', false,
    'sub-exp-time', 'inv-exp-time', 59900, 'CZK'
  ),
  (
    '10000000-0000-4000-8000-000000000005',
    '00000000-0000-4000-8000-000000000005',
    'expired', now() - interval '40 days', now() - interval '1 minute', false,
    'sub-exp-status', 'inv-exp-status', 59900, 'CZK'
  ),
  (
    '10000000-0000-4000-8000-000000000006',
    '00000000-0000-4000-8000-000000000006',
    'revoked', now() - interval '10 days', now() + interval '10 days', false,
    'sub-revoked', 'inv-revoked', 59900, 'CZK'
  ),
  (
    '10000000-0000-4000-8000-000000000007',
    '00000000-0000-4000-8000-000000000007',
    'active', now() - interval '1 day', now() + interval '20 days', false,
    'sub-delete', 'inv-delete', 59900, 'CZK'
  );

insert into public.places (id, name, category, lat, lng)
values
  (
    '20000000-0000-4000-8000-000000000001',
    'Map only pin', 'nature', 50.08, 14.42
  ),
  (
    '20000000-0000-4000-8000-000000000002',
    'Challenge pin', 'historical', 49.94, 14.15
  );

insert into public.challenges (
  id, slug, access_mode, pricing_type, status, is_promo
)
values (
  '30000000-0000-4000-8000-000000000001',
  'vandery-plus-open-fixture',
  'open',
  'free',
  'published',
  false
);

insert into public.waypoints (
  id, challenge_id, sort_order, lat, lng, place_id
)
values (
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  0,
  49.94,
  14.15,
  '20000000-0000-4000-8000-000000000002'
);

-- ---------------------------------------------------------------------------
-- DB-01 … DB-05  has_active_vandery_plus
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.has_active_vandery_plus('00000000-0000-4000-8000-000000000002'),
  true,
  'DB-01 active membership is active'
);

reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000003', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.has_active_vandery_plus('00000000-0000-4000-8000-000000000003'),
  true,
  'DB-02 soft-cancel stays active until expires_at'
);

reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000004', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000004","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.has_active_vandery_plus('00000000-0000-4000-8000-000000000004'),
  false,
  'DB-03a active status with past expires_at is not active'
);

reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000005', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.has_active_vandery_plus('00000000-0000-4000-8000-000000000005'),
  false,
  'DB-03b status=expired is not active'
);

reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000006', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000006","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.has_active_vandery_plus('00000000-0000-4000-8000-000000000006'),
  false,
  'DB-04 revoked is not active'
);

reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.has_active_vandery_plus('00000000-0000-4000-8000-000000000001'),
  false,
  'DB-05 user with no row is not active'
);

-- ---------------------------------------------------------------------------
-- DB-06 non-member map visit
-- ---------------------------------------------------------------------------

select throws_ok(
  $$select public.record_place_visit(
      '20000000-0000-4000-8000-000000000001', 'map')$$,
  'P0001',
  'membership_required',
  'DB-06 map visit without membership'
);

select is(
  (
    select count(*)::int
    from public.place_visits
    where user_id = '00000000-0000-4000-8000-000000000001'
      and place_id = '20000000-0000-4000-8000-000000000001'
  ),
  0,
  'DB-06 writes no place_visits row'
);

select throws_ok(
  $$insert into public.place_visits (user_id, place_id, source)
    values (
      '00000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000001',
      'map'
    )$$,
  '42501',
  'row-level security',
  'DB-06 direct map insert is denied'
);

select throws_ok(
  $$select public.record_place_visit(
      '20000000-0000-4000-8000-000000000001', 'verify')$$,
  '22023',
  'invalid source',
  'DB-17 verify via record_place_visit is invalid_parameter_value'
);

select throws_ok(
  $$select public.record_place_visits_batch(
      array['20000000-0000-4000-8000-000000000001']::uuid[],
      'verify')$$,
  '22023',
  'invalid source',
  'DB-18 verify via record_place_visits_batch is invalid_parameter_value'
);

select throws_ok(
  $$insert into public.place_visits (user_id, place_id, source)
    values (
      '00000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000001',
      'verify'
    )$$,
  '42501',
  'row-level security',
  'DB-19 direct INSERT source=verify fails RLS'
);

select throws_ok(
  $$select public.record_place_visits_batch(
      array['20000000-0000-4000-8000-000000000001']::uuid[],
      'prefs_sync')$$,
  'P0001',
  'membership_required',
  'prefs_sync for a non-member with no visits stays denied'
);

-- ---------------------------------------------------------------------------
-- DB-08 expired and revoked map visit
-- ---------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000004', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000004","role":"authenticated"}',
  true
);
set local role authenticated;

select throws_ok(
  $$select public.record_place_visit(
      '20000000-0000-4000-8000-000000000001', 'map')$$,
  'P0001',
  'membership_required',
  'DB-08 expired map visit'
);

reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000006', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000006","role":"authenticated"}',
  true
);
set local role authenticated;

select throws_ok(
  $$select public.record_place_visit(
      '20000000-0000-4000-8000-000000000001', 'map')$$,
  'P0001',
  'membership_required',
  'DB-08 revoked map visit'
);

-- ---------------------------------------------------------------------------
-- DB-07 member map visit, then DB-11 score +1 not +2
-- ---------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;

select lives_ok(
  $$select public.record_place_visit(
      '20000000-0000-4000-8000-000000000001', 'map')$$,
  'DB-07 member map visit'
);

select is(
  (
    select count(*)::int
    from public.place_visits
    where user_id = '00000000-0000-4000-8000-000000000002'
      and place_id = '20000000-0000-4000-8000-000000000001'
      and source = 'map'
  ),
  1,
  'DB-07 one place_visits row'
);

select is(
  (select place_points from public.get_my_score()),
  1,
  'DB-11 places_count +1'
);
select is(
  (select challenge_points from public.get_my_score()),
  0,
  'DB-11 no challenge bonus'
);
select is(
  (select total_points from public.get_my_score()),
  1,
  'DB-11 points +1 not +2'
);

select throws_ok(
  $$select public.record_place_visit(
      '20000000-0000-4000-8000-000000000001', 'verify')$$,
  '22023',
  'invalid source',
  'DB-17 member record_place_visit source=verify is still 22023'
);

select lives_ok(
  $$select public.record_place_visits_batch(
      array['20000000-0000-4000-8000-000000000001']::uuid[],
      'prefs_sync')$$,
  'prefs_sync for a member is unchanged'
);

-- ---------------------------------------------------------------------------
-- DB-09 challenge verify without membership
-- ---------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select lives_ok(
  $$select public.verify_waypoint(
      '40000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000001/shot.jpg')$$,
  'DB-09 verify_waypoint without membership'
);

select is(
  (
    select count(*)::int
    from public.place_visits
    where user_id = '00000000-0000-4000-8000-000000000001'
      and place_id = '20000000-0000-4000-8000-000000000002'
      and source = 'verify'
  ),
  1,
  'DB-09 place_visits source=verify written'
);

-- ---------------------------------------------------------------------------
-- DB-10 same place via map + verify dedupes
-- ---------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;

select lives_ok(
  $$select public.record_place_visit(
      '20000000-0000-4000-8000-000000000002', 'map')$$,
  'DB-10 member map visit of the challenge place'
);

select lives_ok(
  $$select public.verify_waypoint(
      '40000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000002/shot.jpg')$$,
  'DB-10 verify of the same place'
);

select is(
  (
    select count(*)::int
    from public.place_visits
    where user_id = '00000000-0000-4000-8000-000000000002'
      and place_id = '20000000-0000-4000-8000-000000000002'
  ),
  1,
  'DB-10 primary key keeps a single row'
);

-- ---------------------------------------------------------------------------
-- DB-12 leaderboard formula has no membership bonus
-- ---------------------------------------------------------------------------

reset role;

select ok(
  position(
    'membership_bonus' in pg_get_functiondef('public.leaderboard_rows()'::regprocedure)
  ) = 0,
  'DB-12 leaderboard_rows has no membership_bonus'
);

select ok(
  position(
    'coalesce(p.place_points, 0) + coalesce(ch.challenge_points, 0)'
    in pg_get_functiondef('public.leaderboard_rows()'::regprocedure)
  ) > 0,
  'DB-12 points = place_points + challenge_points'
);

select ok(
  position(
    'membership_bonus' in pg_get_functiondef('public.get_my_score()'::regprocedure)
  ) = 0
  and position(
    'membership_bonus' in pg_get_functiondef('public.get_leaderboard(integer)'::regprocedure)
  ) = 0,
  'DB-12 score RPCs have no membership bonus'
);

-- ---------------------------------------------------------------------------
-- DB-13 / DB-14 RLS
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (
    select count(*)::int
    from public.vandery_plus_memberships
    where user_id = '00000000-0000-4000-8000-000000000003'
  ),
  0,
  'DB-13 cannot select another user membership'
);

select is(
  (
    select count(*)::int
    from public.vandery_plus_memberships
    where user_id = '00000000-0000-4000-8000-000000000002'
  ),
  1,
  'DB-13 can select own membership'
);

select throws_ok(
  $$insert into public.vandery_plus_memberships (user_id, status, expires_at)
    values (
      '00000000-0000-4000-8000-000000000002',
      'active',
      now() + interval '30 days'
    )$$,
  '42501',
  'row-level security',
  'DB-14 authenticated insert denied'
);

update public.vandery_plus_memberships
set status = 'revoked'
where user_id = '00000000-0000-4000-8000-000000000002';

select is(
  (
    select status
    from public.vandery_plus_memberships
    where user_id = '00000000-0000-4000-8000-000000000002'
  ),
  'active',
  'DB-14 authenticated update does not change status'
);

select throws_ok(
  $$select public.commit_vandery_plus_event(
      '10000000-0000-4000-8000-000000000002',
      '00000000-0000-4000-8000-000000000002',
      'paid_first:client',
      'paid_first',
      'client',
      '{"status":"active"}'::jsonb
    )$$,
  '42501',
  'DB-14 client cannot commit a webhook'
);

-- ---------------------------------------------------------------------------
-- DB-15 second current row
-- ---------------------------------------------------------------------------

reset role;

select throws_ok(
  $$insert into public.vandery_plus_memberships (user_id, status, expires_at)
    values (
      '00000000-0000-4000-8000-000000000002',
      'pending',
      now()
    )$$,
  '23505',
  'DB-15 second current row violates the partial unique index'
);

-- ---------------------------------------------------------------------------
-- DB-16 anonymize on account delete, do not hard-delete
-- ---------------------------------------------------------------------------

delete from auth.users where id = '00000000-0000-4000-8000-000000000007';

select is(
  (
    select count(*)::int
    from public.vandery_plus_memberships
    where id = '10000000-0000-4000-8000-000000000007'
  ),
  1,
  'DB-16 membership row is kept'
);

select ok(
  (
    select user_id is null
    from public.vandery_plus_memberships
    where id = '10000000-0000-4000-8000-000000000007'
  ),
  'DB-16 user_id tombstone is null'
);

select ok(
  (
    select anonymized_at is not null
    from public.vandery_plus_memberships
    where id = '10000000-0000-4000-8000-000000000007'
  ),
  'DB-16 anonymized_at is set'
);

select is(
  (
    select fapi_subscription_id
    from public.vandery_plus_memberships
    where id = '10000000-0000-4000-8000-000000000007'
  ),
  null,
  'DB-16 subscription id cleared'
);

select is(
  (
    select amount_cents
    from public.vandery_plus_memberships
    where id = '10000000-0000-4000-8000-000000000007'
  ),
  59900,
  'DB-16 amount kept as the accounting trace'
);

select is(
  (
    select fapi_invoice_id
    from public.vandery_plus_memberships
    where id = '10000000-0000-4000-8000-000000000007'
  ),
  'inv-delete',
  'DB-16 invoice id kept as the accounting trace'
);

-- ---------------------------------------------------------------------------
-- Commit idempotency (supports ED-05 / ED-06 at the database boundary)
-- ---------------------------------------------------------------------------

select is(
  (
    public.commit_vandery_plus_event(
      '10000000-0000-4000-8000-000000000002',
      '00000000-0000-4000-8000-000000000099',
      'paid_first:mismatch',
      'paid_first',
      'mismatch',
      '{"status":"revoked"}'::jsonb
    ) ->> 'reason'
  ),
  'user_mismatch',
  'commit rejects a user that is not the checkout row'
);

select is(
  (
    select status
    from public.vandery_plus_memberships
    where id = '10000000-0000-4000-8000-000000000002'
  ),
  'active',
  'mismatched commit does not change status'
);

select lives_ok(
  $$select public.commit_vandery_plus_event(
      '10000000-0000-4000-8000-000000000002',
      '00000000-0000-4000-8000-000000000002',
      'renew:inv-renew-1',
      'renew',
      'inv-renew-1',
      jsonb_build_object(
        'status', 'active',
        'expires_at', '2030-02-01T00:00:00Z',
        'cancel_at_period_end', false,
        'fapi_invoice_id', 'inv-renew-1'
      )
    )$$,
  'first renew commit applies'
);

select is(
  (
    public.commit_vandery_plus_event(
      '10000000-0000-4000-8000-000000000002',
      '00000000-0000-4000-8000-000000000002',
      'renew:inv-renew-1',
      'renew',
      'inv-renew-1',
      jsonb_build_object(
        'status', 'active',
        'expires_at', '2031-02-01T00:00:00Z'
      )
    ) ->> 'idempotent'
  ),
  'true',
  'second renew commit is idempotent'
);

select is(
  (
    select expires_at
    from public.vandery_plus_memberships
    where id = '10000000-0000-4000-8000-000000000002'
  ),
  '2030-02-01T00:00:00Z'::timestamptz,
  'idempotent replay does not move expires_at again'
);

select is(
  (
    public.commit_vandery_plus_event(
      '10000000-0000-4000-8000-000000000002',
      '00000000-0000-4000-8000-000000000002',
      'paid_first:inv-renew-1',
      'paid_first',
      'inv-renew-1',
      jsonb_build_object(
        'status', 'active',
        'expires_at', '2032-02-01T00:00:00Z'
      )
    ) ->> 'idempotent'
  ),
  'true',
  'DB-20 same invoice id does not extend when the kind prefix changes'
);

insert into public.vandery_plus_webhook_events (
  idempotency_key, event_kind, fapi_invoice_id
)
values ('paid_first:inv-db20', 'paid_first', 'inv-db20');

select throws_ok(
  $$insert into public.vandery_plus_webhook_events (
      idempotency_key, event_kind, fapi_invoice_id
    )
    values ('renew:inv-db20', 'renew', 'inv-db20')$$,
  '23505',
  'DB-20 partial unique index blocks a second paid invoice id'
);

insert into public.vandery_plus_memberships (
  id, user_id, status, expires_at
)
values (
  '10000000-0000-4000-8000-000000000011',
  '00000000-0000-4000-8000-000000000001',
  'pending',
  now()
);

select is(
  (
    public.commit_vandery_plus_event(
      '10000000-0000-4000-8000-000000000011',
      '00000000-0000-4000-8000-000000000001',
      'ignored',
      'payment_failed',
      'inv-x',
      '{"status":"failed"}'::jsonb
    ) ->> 'membership_status'
  ),
  'failed',
  'DB-21 payment_failed leaves the checkout failed'
);

select is(
  (
    public.commit_vandery_plus_event(
      '10000000-0000-4000-8000-000000000011',
      '00000000-0000-4000-8000-000000000001',
      'ignored',
      'paid_first',
      'inv-x',
      jsonb_build_object(
        'status', 'active',
        'expires_at', '2030-01-01T00:00:00Z'
      )
    ) ->> 'membership_status'
  ),
  'active',
  'DB-21 paid_first after payment_failed on the same invoice activates'
);

select is(
  (
    public.commit_vandery_plus_event(
      '10000000-0000-4000-8000-000000000011',
      '00000000-0000-4000-8000-000000000001',
      'ignored',
      'renew',
      'inv-y1',
      jsonb_build_object('expires_at', '2030-02-01T00:00:00Z', 'status', 'active')
    ) ->> 'idempotent'
  ),
  'false',
  'DB-22 first renew invoice is applied'
);

select is(
  (
    public.commit_vandery_plus_event(
      '10000000-0000-4000-8000-000000000011',
      '00000000-0000-4000-8000-000000000001',
      'ignored',
      'renew',
      'inv-y2',
      jsonb_build_object('expires_at', '2030-03-01T00:00:00Z', 'status', 'active')
    ) ->> 'idempotent'
  ),
  'false',
  'DB-22 second renew invoice is applied'
);

select is(
  (
    select expires_at
    from public.vandery_plus_memberships
    where id = '10000000-0000-4000-8000-000000000011'
  ),
  '2030-03-01T00:00:00Z'::timestamptz,
  'DB-22 second renew invoice adds another month'
);

-- T8: own diploma rows only, no client insert, catalog starts empty.
select is(
  (select count(*)::int from public.vandery_plus_diplomas),
  0,
  'T8 catalog has no placeholder production titles'
);

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;

select throws_ok(
  $$insert into public.vandery_plus_user_diplomas (user_id, diploma_id)
    values (
      '00000000-0000-4000-8000-000000000002',
      '50000000-0000-4000-8000-000000000001'
    )$$,
  '42501',
  'T8 authenticated cannot insert a diploma unlock'
);

select * from finish();

rollback;
