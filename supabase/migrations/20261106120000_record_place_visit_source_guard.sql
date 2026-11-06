-- Fix: client cannot write place_visits.source = 'verify' (map-gate bypass).
-- Depends on 20261106113000_vandery_plus_membership.sql (PR #52).
--
-- Why this is safe:
--   * verify_waypoint (SECURITY DEFINER, owner postgres, rolbypassrls = true)
--     inserts source = 'verify' directly and does NOT call can_record_place_visit,
--     record_place_visit or the INSERT policy -> unaffected (DB-09, E2E-07).
--   * Flutter never sends PlaceVisitSource.verify (only map / prefs_sync).
--   * can_record_place_visit is the single predicate used by the INSERT policy
--     and both RPCs, so one change closes RPC, batch RPC and direct PostgREST insert.

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
    -- Server-only source. Written exclusively by verify_waypoint (definer,
    -- bypasses RLS). Client paths (policy + RPCs) must never accept it.
    return false;
  end if;
  if p_source = 'map' then
    return public.has_active_vandery_plus(uid);
  end if;
  if p_source = 'prefs_sync' then
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
  -- 'verify' is server-only (verify_waypoint). Reject explicitly.
  if p_source is null or p_source not in ('map', 'prefs_sync') then
    raise exception 'invalid source' using errcode = '22023';
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
  if p_source is null or p_source not in ('map', 'prefs_sync') then
    raise exception 'invalid source' using errcode = '22023';
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

-- Grants unchanged vs PR #52 / prod (CREATE OR REPLACE keeps ACL); restated for clarity.
revoke all on function public.can_record_place_visit(text) from public, anon;
grant execute on function public.can_record_place_visit(text) to authenticated, service_role;
revoke all on function public.record_place_visit(uuid, text) from public, anon;
revoke all on function public.record_place_visits_batch(uuid[], text) from public, anon;
grant execute on function public.record_place_visit(uuid, text) to authenticated, service_role;
grant execute on function public.record_place_visits_batch(uuid[], text) to authenticated, service_role;

comment on function public.record_place_visit(uuid, text) is
  'Records one place visit (client). source in (map, prefs_sync). map requires active VANDERY+. source=verify is server-only (verify_waypoint).';

-- place_visits_insert_own policy is unchanged: it calls can_record_place_visit(source),
-- which now returns false for 'verify', so a direct INSERT with source='verify' is denied.
