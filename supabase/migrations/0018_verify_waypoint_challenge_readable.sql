-- H3: verify_waypoint uses the catalog promo gate.
--
-- Live public.verify_waypoint (survey 2026-10-02) checks published status,
-- purchase/free, story n+1, and the photo-path prefix, then returns story
-- step ids. It does not call private.challenge_readable, so an exclusive
-- is_promo challenge can be verified by UUID without an audience match.
--
-- This replace keeps that body, including story-step ids when
-- public.challenge_story_steps exists (prod has the table; a database that
-- only applied 0001–0015 does not). Unpublished and exclusive challenges
-- the caller cannot read both raise 'challenge not published'.
--
-- public.challenge_readable is the wrapper start-fapi-checkout calls with
-- the user JWT. private.challenge_readable (0015) stays the source of truth.
--
-- Numbered 0018 so it does not collide with 0016_challenge_story_steps and
-- 0017_verify_waypoint_story_enrich. Prod already has those story objects
-- under timestamp migration versions. Apply this after those story
-- migrations when both are on the same database, so this replace stays
-- the verify_waypoint definition. Apply it before deploying
-- start-fapi-checkout. This file does not run itself.

create or replace function public.challenge_readable(p_challenge_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select private.challenge_readable(p_challenge_id);
$$;

comment on function public.challenge_readable(uuid) is
  'True when the caller may see this challenge: published, and a live promo match when is_promo. Same rule as catalog RLS.';

revoke all on function public.challenge_readable(uuid) from public;
revoke all on function public.challenge_readable(uuid) from anon;
grant execute on function public.challenge_readable(uuid) to authenticated;

create or replace function public.verify_waypoint(p_waypoint_id uuid, p_photo_path text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  wp public.waypoints%rowtype;
  ch public.challenges%rowtype;
  purchased boolean;
  prev_id uuid;
  prev_done boolean;
  remaining integer;
  next_wp_id uuid;
  next_step_id uuid;
  closing_step_id uuid;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if p_photo_path is null or length(trim(p_photo_path)) = 0 then
    raise exception 'photo required';
  end if;
  if p_photo_path not like uid::text || '/%' then
    raise exception 'invalid photo path';
  end if;

  select * into wp from public.waypoints where id = p_waypoint_id;
  if not found then
    raise exception 'waypoint not found';
  end if;

  select * into ch
  from public.challenges
  where id = wp.challenge_id;
  if not found or not private.challenge_readable(ch.id) then
    raise exception 'challenge not published';
  end if;

  purchased := ch.pricing_type = 'free' or exists (
    select 1
    from public.purchases
    where user_id = uid
      and challenge_id = ch.id
      and status = 'paid'
  );
  if not purchased then
    raise exception 'purchase required';
  end if;

  if ch.access_mode = 'story' then
    select w.id into prev_id
    from public.waypoints w
    where w.challenge_id = ch.id
      and w.sort_order = wp.sort_order - 1;
    if prev_id is not null then
      select exists (
        select 1
        from public.waypoint_progress
        where user_id = uid and waypoint_id = prev_id
      ) into prev_done;
      if not prev_done then
        raise exception 'previous waypoint incomplete';
      end if;
    end if;
  end if;

  insert into public.challenge_progress (user_id, challenge_id, status)
  values (uid, ch.id, 'in_progress')
  on conflict (user_id, challenge_id) do nothing;

  insert into public.waypoint_progress (user_id, waypoint_id, photo_path)
  values (uid, p_waypoint_id, p_photo_path)
  on conflict (user_id, waypoint_id) do update
    set photo_path = excluded.photo_path, completed_at = now();

  select count(*) into remaining
  from public.waypoints w
  where w.challenge_id = ch.id
    and not exists (
      select 1
      from public.waypoint_progress p
      where p.user_id = uid and p.waypoint_id = w.id
    );

  if remaining = 0 then
    update public.challenge_progress
      set status = 'completed', completed_at = now()
      where user_id = uid and challenge_id = ch.id;
  end if;

  insert into public.place_visits (user_id, place_id, source)
  values (uid, wp.place_id, 'verify')
  on conflict (user_id, place_id) do nothing;

  next_step_id := null;
  closing_step_id := null;
  next_wp_id := null;
  if ch.access_mode = 'story'
     and to_regclass('public.challenge_story_steps') is not null then
    if remaining = 0 then
      select s.id into closing_step_id
      from public.challenge_story_steps s
      where s.challenge_id = ch.id and s.kind = 'closing'
      limit 1;
    else
      select w.id into next_wp_id
      from public.waypoints w
      where w.challenge_id = ch.id
        and w.sort_order = wp.sort_order + 1
      limit 1;
      if next_wp_id is not null then
        select s.id into next_step_id
        from public.challenge_story_steps s
        where s.challenge_id = ch.id
          and s.kind = 'before_waypoint'
          and s.waypoint_id = next_wp_id
        limit 1;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'remaining', remaining,
    'challenge_id', ch.id,
    'unlocked_waypoint_id', next_wp_id,
    'next_story_step_id', next_step_id,
    'closing_story_step_id', closing_step_id
  );
end;
$$;

comment on function public.verify_waypoint(uuid, text) is
  'Verifies a waypoint for auth.uid(). Exclusive challenges require private.challenge_readable (published + promo match). Does not check GPS or that the storage object exists.';
