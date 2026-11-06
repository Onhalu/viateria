-- Rollback of 20261106120000_record_place_visit_source_guard.sql
-- Restores the exact PR #52 (20261106113000) definitions, comment and grants.
-- WARNING: re-opens the source='verify' map-gate bypass.
--
-- Rollback apply order, newest first:
--   20261106120900 (cancel flag only),
--   20261106120800 (refund_cents beyond int4),
--   20261106120700 (refund key only when applied),
--   20261106120600 (non-numeric refund_cents),
--   20261106120500 (gross-only full refund),
--   20261106120400 (refund parent gate),
--   20261106120300 (drops private.commit, including 120400 through 120900),
--   20261106120200,
--   20261106120100,
--   20261106120000,
--   20261106114000,
--   20261106113000.
-- 20261106113000 may instead be applied alone to the full forward chain.
-- That path requires viateria.allow_destructive_rollback=on before it drops
-- vandery_plus_memberships and vandery_plus_webhook_events.
-- Apply this file after 20261106120300 is rolled back, so
-- public.can_record_place_visit is the plpgsql function again.

-- The transaction starts first. A guard error aborts it, and the final
-- commit rolls that aborted transaction back even when psql continues.

begin;

do $guard$
begin
  if coalesce(current_setting('viateria.allow_destructive_rollback', true), '')
     is distinct from 'on' then
    raise exception 'viateria.allow_destructive_rollback must be on before applying this rollback'
      using errcode = '42501';
  end if;
end
$guard$;

-- Out of order until 120300 has dropped private.commit. The raise aborts
-- this transaction, and the final commit then rolls it back.
do $order$
begin
  if to_regprocedure(
       'private.commit_vandery_plus_event(uuid,uuid,text,text,text,jsonb)'
     ) is not null then
    raise exception 'roll back 20261106120300 before this file; private.commit_vandery_plus_event still exists'
      using errcode = '55000';
  end if;
end
$order$;

create or replace function public.can_record_place_visit(p_source text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    return false;
  end if;
  if p_source = 'verify' then
    -- Challenge verify_waypoint inserts directly. SPEC §6 does not block
    -- source = verify. See T0 residual risk for the client RPC.
    return true;
  end if;
  if p_source = 'map' then
    return public.has_active_vandery_plus(uid);
  end if;
  if p_source = 'prefs_sync' then
    -- DBA default (SPEC §6 Ask): historical sync only, or a member.
    return public.has_active_vandery_plus(uid)
      or exists (
        select 1
        from public.place_visits v
        where v.user_id = uid
      );
  end if;
  return false;
end;
$$;

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
  if not public.can_record_place_visit(p_source) then
    raise exception 'membership_required' using errcode = 'P0001';
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
  if not public.can_record_place_visit(p_source) then
    raise exception 'membership_required' using errcode = 'P0001';
  end if;

  insert into public.place_visits (user_id, place_id, source)
  select distinct uid, p.id, p_source
  from public.places p
  join unnest(coalesce(p_place_ids, array[]::uuid[])) as incoming (id)
    on incoming.id = p.id
  on conflict (user_id, place_id) do nothing;
end;
$$;

revoke all on function public.can_record_place_visit(text) from public, anon;
grant execute on function public.can_record_place_visit(text) to authenticated, service_role;
revoke all on function public.record_place_visit(uuid, text) from public, anon;
revoke all on function public.record_place_visits_batch(uuid[], text) from public, anon;
grant execute on function public.record_place_visit(uuid, text) to authenticated, service_role;
grant execute on function public.record_place_visits_batch(uuid[], text) to authenticated, service_role;

comment on function public.record_place_visit(uuid, text) is
  'Records one place visit. source=map requires an active VANDERY+ membership. verify_waypoint is a separate function and is not gated.';

-- Plain psql -f commits. The pgTAP include sets vandery_rollback_test so
-- this transaction stays open and the test can roll it back.
\if :{?vandery_rollback_test}
\else
commit;
\endif
