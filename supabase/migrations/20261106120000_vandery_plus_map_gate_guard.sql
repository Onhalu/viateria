-- Revertible map-gate guard. Drop this file to restore the previous gate.
-- Final shape is still the owner's decision (variant A).
--
-- Variant A, as applied here:
--   * source=verify is written only by verify_waypoint (security definer).
--   * authenticated INSERT on place_visits is revoked.
--   * record_place_visit accepts only source=map, and only with an active
--     membership.
-- prefs_sync rules are unchanged (pending a separate decision).

revoke insert on table public.place_visits from anon, authenticated;

drop policy if exists place_visits_insert_own on public.place_visits;

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
    -- Only verify_waypoint may insert this source. It does not call this RPC.
    return false;
  end if;
  if p_source = 'map' then
    return public.has_active_vandery_plus(uid);
  end if;
  if p_source = 'prefs_sync' then
    -- Unchanged. Historical sync only, or a member.
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

revoke all on function public.can_record_place_visit(text) from public, anon;
grant execute on function public.can_record_place_visit(text)
  to authenticated, service_role;

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
  if p_source is distinct from 'map' then
    raise exception 'invalid source' using errcode = 'P0001';
  end if;
  if not public.can_record_place_visit('map') then
    raise exception 'membership_required' using errcode = 'P0001';
  end if;

  insert into public.place_visits (user_id, place_id, source)
  select uid, p.id, 'map'
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
    raise exception 'invalid source' using errcode = 'P0001';
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

revoke all on function public.record_place_visit(uuid, text) from public, anon;
revoke all on function public.record_place_visits_batch(uuid[], text) from public, anon;
grant execute on function public.record_place_visit(uuid, text) to authenticated;
grant execute on function public.record_place_visits_batch(uuid[], text) to authenticated;

comment on function public.record_place_visit(uuid, text) is
  'Map visit only. Requires an active VANDERY+ membership. source=verify is verify_waypoint, not this RPC.';
