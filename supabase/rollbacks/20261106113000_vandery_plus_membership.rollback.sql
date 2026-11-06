-- Rollback of 20261106113000 and every later VANDERY+ migration through
-- 20261106120400. Drops private.* so this file still runs after 120300.
--
-- Rollback apply order, newest first:
--   20261106120300 (drops private.commit, including the 120400 refund gate),
--   20261106120200,
--   20261106120100,
--   20261106120000,
--   20261106114000,
--   20261106113000.
-- This file may instead be applied alone to the full forward chain.
-- It requires viateria.allow_destructive_rollback=on before it drops
-- vandery_plus_memberships and vandery_plus_webhook_events.
-- Does not change ON DELETE behaviour of purchases or challenge_diplomas.
-- Does not drop the diploma catalog.
--
-- The transaction starts first. A guard error aborts it, and the final
-- commit rolls that aborted transaction back even when psql continues.

begin;

do $guard$
begin
  if coalesce(current_setting('viateria.allow_destructive_rollback', true), '')
     is distinct from 'on' then
    raise exception 'viateria.allow_destructive_rollback must be on before dropping memberships and webhook tombstones'
      using errcode = '42501';
  end if;
end
$guard$;

drop trigger if exists vandery_plus_anonymize_on_profile_delete on public.profiles;
drop trigger if exists vandery_plus_memberships_touch on public.vandery_plus_memberships;

-- The insert policy calls can_record_place_visit. Drop it before the function
-- or PostgreSQL raises 2BP01.
drop policy if exists place_visits_insert_own on public.place_visits;

-- Public SQL wrappers depend on private.*. Drop the wrappers first.
drop function if exists public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb);
drop function if exists public.can_record_place_visit(text);
drop function if exists public.has_active_vandery_plus(uuid);
drop function if exists public.anonymize_vandery_plus_before_profile_delete();
drop function if exists public.anonymize_vandery_plus_membership(uuid);
drop function if exists public.touch_vandery_plus_membership();

drop function if exists private.anonymize_vandery_plus_before_profile_delete();
drop function if exists private.anonymize_vandery_plus_membership(uuid);
drop function if exists private.touch_vandery_plus_membership();
drop function if exists private.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb);
drop function if exists private.can_record_place_visit(text);
drop function if exists private.has_active_vandery_plus(uuid);

-- Leaderboard RPCs as they were in 0011_leaderboard.sql.
create or replace function public.record_place_visit(
  p_place_id uuid,
  p_source text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if p_source is null or p_source not in ('map', 'verify', 'prefs_sync') then
    raise exception 'invalid source';
  end if;

  insert into public.place_visits (user_id, place_id, source)
  select uid, p.id, p_source
  from public.places p
  where p.id = p_place_id
  on conflict (user_id, place_id) do nothing;
end;
$$;

create or replace function public.record_place_visits_batch(
  p_place_ids uuid[],
  p_source text default 'prefs_sync'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if p_source is null or p_source not in ('map', 'verify', 'prefs_sync') then
    raise exception 'invalid source';
  end if;

  insert into public.place_visits (user_id, place_id, source)
  select distinct uid, p.id, p_source
  from public.places p
  join unnest(coalesce(p_place_ids, array[]::uuid[])) as incoming (id)
    on incoming.id = p.id
  on conflict (user_id, place_id) do nothing;
end;
$$;

revoke all on function public.record_place_visit(uuid, text) from public, anon;
revoke all on function public.record_place_visits_batch(uuid[], text) from public, anon;
grant execute on function public.record_place_visit(uuid, text) to authenticated;
grant execute on function public.record_place_visits_batch(uuid[], text) to authenticated;

-- CREATE OR REPLACE keeps the VANDERY+ comment. Clear it.
comment on function public.record_place_visit(uuid, text) is null;
comment on function public.record_place_visits_batch(uuid[], text) is null;

create policy place_visits_insert_own
  on public.place_visits
  for insert
  to authenticated
  with check (user_id = auth.uid());

drop table if exists public.vandery_plus_webhook_events;
drop table if exists public.vandery_plus_memberships;

-- Plain psql -f commits. The pgTAP include sets vandery_rollback_test so
-- this transaction stays open and the test can roll it back.
\if :{?vandery_rollback_test}
\else
commit;
\endif
