-- SPEC-challenge-places (SCHVÁLENO): place_id required, verify uses that id.
--
-- DO NOT APPLY until unmatched published waypoints = 0.
-- Parent CMS-fixes first, then runs this file on yzmbxxgesnbsqygzgdky.
--
-- Known row the 50 m backfill in 0013 cannot fill (55.5 m):
--   published waypoint 95f6584b-45be-4b57-9af8-12a10b2a2a2d
--   (Zelená Hora, challenge slug vyzva-zdarma)
--   place „Poutní kostel sv. Jana Nepomuckého na Zelené Hoře“
-- Parent UPDATEs waypoints.place_id for that UUID. This file does not
-- guess the place uuid.
--
-- NOT NULL covers every waypoint row, including drafts. The guard below
-- refuses the migration while any place_id is null, and the error reports
-- how many of those nulls are on published challenges.
--
-- If 0013 assigned the same nearest place to two stops in one challenge,
-- the unique index fails. Repoint those rows in the CMS before re-running.

do $$
declare
  missing_all integer;
  missing_published integer;
begin
  select count(*) into missing_all
  from public.waypoints
  where place_id is null;

  select count(*) into missing_published
  from public.waypoints w
  join public.challenges c on c.id = w.challenge_id
  where w.place_id is null
    and c.status = 'published';

  if missing_all > 0 then
    raise exception
      '0014 refused: % waypoint(s) have null place_id (% published). Apply only when unmatched published = 0. CMS-fix 95f6584b-45be-4b57-9af8-12a10b2a2a2d (Zelená Hora, vyzva-zdarma) before this migration.',
      missing_all,
      missing_published;
  end if;
end $$;

alter table public.waypoints
  alter column place_id set not null;

create unique index if not exists waypoints_challenge_place_uidx
  on public.waypoints (challenge_id, place_id);

comment on column public.waypoints.place_id is
  'Required catalog place for this stop. Map tint, list/planner coordinates, and verify_waypoint use this id.';

-- Successful verify records wp.place_id. No nearest-place search.
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
  where id = wp.challenge_id and status = 'published';
  if not found then
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

  return jsonb_build_object('remaining', remaining, 'challenge_id', ch.id);
end;
$$;
