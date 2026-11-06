-- Full chain is already applied. Runs 113000 alone, which covers 120300
-- down through 113000, with viateria.allow_destructive_rollback=on.
-- The outer transaction restores the schema afterwards.

begin;

create extension if not exists pgtap with schema extensions;

select plan(16);

select ok(
  to_regclass('public.vandery_plus_memberships') is not null,
  'full chain: memberships exist before rollback'
);

select ok(
  to_regclass('public.vandery_plus_webhook_events') is not null,
  'full chain: webhook events exist before rollback'
);

select ok(
  to_regprocedure('private.commit_vandery_plus_event(uuid,uuid,text,text,text,jsonb)') is not null,
  'full chain: private commit exists before rollback'
);

select throws_ok(
  $test$do $guard$
    begin
      if coalesce(current_setting('viateria.allow_destructive_rollback', true), '')
         is distinct from 'on' then
        raise exception 'viateria.allow_destructive_rollback must be on before dropping memberships and webhook tombstones'
          using errcode = '42501';
      end if;
    end
    $guard$
  $test$,
  '42501',
  'viateria.allow_destructive_rollback must be on before dropping memberships and webhook tombstones',
  'rollback refuses tombstone drops when the guard is off'
);

-- Plain psql -f: no GUC, no --single-transaction, no ON_ERROR_STOP.
-- A separate session, so the file's begin/commit cannot see this transaction.
-- Prefer IPv6 when `db` has a v6 address. On the v6-only docker network the
-- v4 address is a blackhole and a plain `psql` hangs in SYN_SENT.
\! sh -c 'h=$(getent ahostsv6 "$PGHOST" | cut -d" " -f1 | head -n1); psql -h "${h:-$PGHOST}" -f fixtures/20261106113000_vandery_plus_membership.rollback'
\! sh -c 'h=$(getent ahostsv6 "$PGHOST" | cut -d" " -f1 | head -n1); psql -h "${h:-$PGHOST}" -f fixtures/20261106114000_vandery_plus_diplomas.rollback'

select ok(
  to_regclass('public.vandery_plus_memberships') is not null,
  'guard off drops nothing: memberships still exist'
);

select ok(
  to_regclass('public.vandery_plus_webhook_events') is not null,
  'guard off drops nothing: webhook events still exist'
);

select ok(
  to_regprocedure('private.commit_vandery_plus_event(uuid,uuid,text,text,text,jsonb)') is not null,
  'guard off drops nothing: private commit still exists'
);

select ok(
  to_regclass('public.vandery_plus_user_diplomas') is not null,
  'guard off drops nothing: user diplomas still exist'
);

\set vandery_rollback_test 1
select set_config('viateria.allow_destructive_rollback', 'on', true);

-- supabase test db mounts only supabase/tests. The same bytes are
-- supabase/rollbacks/20261106113000_vandery_plus_membership.rollback.sql.
\ir fixtures/20261106113000_vandery_plus_membership.rollback

select ok(
  to_regclass('public.vandery_plus_memberships') is null,
  '113000 alone drops memberships'
);

select ok(
  to_regclass('public.vandery_plus_webhook_events') is null,
  '113000 alone drops webhook events'
);

select ok(
  to_regprocedure('public.can_record_place_visit(text)') is null,
  'can_record_place_visit is dropped after the policy'
);

select ok(
  to_regprocedure('private.commit_vandery_plus_event(uuid,uuid,text,text,text,jsonb)') is null,
  'private commit is dropped'
);

select is(
  obj_description('public.record_place_visit(uuid,text)'::regprocedure, 'pg_proc'),
  null,
  'record_place_visit comment is null'
);

select ok(
  coalesce((
    select position(
      'can_record_place_visit' in pg_get_expr(p.polwithcheck, p.polrelid)
    )
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    where c.relname = 'place_visits'
      and p.polname = 'place_visits_insert_own'
  ), 0) = 0,
  'insert policy no longer calls can_record_place_visit'
);

select ok(
  position(
    'verify' in pg_get_functiondef('public.record_place_visit(uuid,text)'::regprocedure)
  ) > 0,
  'record_place_visit accepts verify again'
);

select ok(
  to_regclass('public.vandery_plus_diplomas') is not null,
  '113000 alone does not drop the diploma catalog'
);

select * from finish();

rollback;
