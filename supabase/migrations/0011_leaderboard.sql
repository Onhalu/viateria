-- All-time leaderboard v1.
--
-- Points: +1 per distinct place_visits row (PK user_id+place_id).
-- Completed challenge (challenge_progress.status = 'completed'):
--   easy or null difficulty → 3, normal → 4, hard → 5.
-- Display names are read from public.profiles inside these RPCs only.
-- Email is never selected.

alter table public.profiles
  add column if not exists avatar_url text;

comment on column public.profiles.avatar_url is
  'Optional avatar URL. Leaderboard RPCs may return it. Email is never selected.';

create table if not exists public.place_visits (
  user_id uuid not null references auth.users (id) on delete cascade,
  place_id uuid not null references public.places (id) on delete cascade,
  source text not null,
  visited_at timestamptz not null default now(),
  primary key (user_id, place_id)
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'place_visits_source_check'
      and conrelid = 'public.place_visits'::regclass
  ) then
    alter table public.place_visits
      add constraint place_visits_source_check
      check (source in ('map', 'verify', 'prefs_sync'));
  end if;
end $$;

create index if not exists place_visits_user_visited_idx
  on public.place_visits (user_id, visited_at);

create index if not exists challenge_progress_completed_user_idx
  on public.challenge_progress (user_id)
  where status = 'completed';

comment on table public.place_visits is
  'One row per user and place. Duplicates are ignored so a place scores once.';

alter table public.place_visits enable row level security;

drop policy if exists place_visits_select_own on public.place_visits;
create policy place_visits_select_own
  on public.place_visits
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists place_visits_insert_own on public.place_visits;
create policy place_visits_insert_own
  on public.place_visits
  for insert
  to authenticated
  with check (user_id = auth.uid());

grant select, insert on table public.place_visits to authenticated;

-- Ranked rows for every user with points. Not granted to the API.
-- Tie-break: higher points, then earlier first visit, then user_id.
create or replace function public.leaderboard_rows()
returns table (
  user_id uuid,
  display_name text,
  avatar_url text,
  total_points integer,
  place_points integer,
  challenge_points integer,
  rank integer
)
language sql
stable
security definer
set search_path = public
as $$
  with place_pts as (
    select
      v.user_id,
      count(*)::integer as place_points,
      min(v.visited_at) as first_visit
    from public.place_visits v
    group by v.user_id
  ),
  challenge_pts as (
    select
      cp.user_id,
      sum(
        case
          when c.difficulty = 'hard' then 5
          when c.difficulty = 'normal' then 4
          else 3
        end
      )::integer as challenge_points
    from public.challenge_progress cp
    join public.challenges c on c.id = cp.challenge_id
    where cp.status = 'completed'
    group by cp.user_id
  ),
  combined as (
    select
      coalesce(p.user_id, ch.user_id) as user_id,
      coalesce(p.place_points, 0) as place_points,
      coalesce(ch.challenge_points, 0) as challenge_points,
      coalesce(p.place_points, 0) + coalesce(ch.challenge_points, 0) as total_points,
      p.first_visit
    from place_pts p
    full outer join challenge_pts ch on ch.user_id = p.user_id
  )
  select
    comb.user_id,
    pr.display_name,
    pr.avatar_url,
    comb.total_points,
    comb.place_points,
    comb.challenge_points,
    row_number() over (
      order by
        comb.total_points desc,
        comb.first_visit asc nulls last,
        comb.user_id asc
    )::integer as rank
  from combined comb
  join public.profiles pr on pr.id = comb.user_id
  where comb.total_points > 0;
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

create or replace function public.get_leaderboard(p_limit integer default 50)
returns table (
  user_id uuid,
  display_name text,
  avatar_url text,
  total_points integer,
  place_points integer,
  challenge_points integer,
  rank integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 0), 50);
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  return query
  select
    board.user_id,
    board.display_name,
    board.avatar_url,
    board.total_points,
    board.place_points,
    board.challenge_points,
    board.rank
  from public.leaderboard_rows() as board
  order by board.rank
  limit v_limit;
end;
$$;

create or replace function public.get_my_score()
returns table (
  user_id uuid,
  display_name text,
  avatar_url text,
  total_points integer,
  place_points integer,
  challenge_points integer,
  rank integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  return query
  select
    board.user_id,
    board.display_name,
    board.avatar_url,
    board.total_points,
    board.place_points,
    board.challenge_points,
    board.rank
  from public.leaderboard_rows() as board
  where board.user_id = uid;

  if found then
    return;
  end if;

  return query
  select
    p.id,
    p.display_name,
    p.avatar_url,
    0,
    0,
    0,
    null::integer
  from public.profiles p
  where p.id = uid;

  if found then
    return;
  end if;

  return query
  select uid, null::text, null::text, 0, 0, 0, null::integer;
end;
$$;

revoke all on function public.leaderboard_rows() from public, anon, authenticated;
revoke all on function public.record_place_visit(uuid, text) from public, anon;
revoke all on function public.record_place_visits_batch(uuid[], text) from public, anon;
revoke all on function public.get_leaderboard(integer) from public, anon;
revoke all on function public.get_my_score() from public, anon;

grant execute on function public.record_place_visit(uuid, text) to authenticated;
grant execute on function public.record_place_visits_batch(uuid[], text) to authenticated;
grant execute on function public.get_leaderboard(integer) to authenticated;
grant execute on function public.get_my_score() to authenticated;

comment on function public.get_leaderboard(integer) is
  'Top-N all-time board. display_name comes from profiles. Email is never selected.';
comment on function public.get_my_score() is
  'Caller score and rank, including when they are outside the top N. Email is never selected.';

-- Successful verify_waypoint also records the nearest place within 50 m.
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

  -- Nearest catalog place within 50 m. PK ignores a place already scored.
  insert into public.place_visits (user_id, place_id, source)
  select uid, picked.id, 'verify'
  from (
    select p.id
    from public.places p
    where (
      6371000.0 * 2.0 * asin(
        least(
          1.0,
          sqrt(
            power(sin(radians(p.lat - wp.lat) / 2.0), 2)
            + cos(radians(wp.lat)) * cos(radians(p.lat))
              * power(sin(radians(p.lng - wp.lng) / 2.0), 2)
          )
        )
      )
    ) <= 50
    order by
      power(sin(radians(p.lat - wp.lat) / 2.0), 2)
      + cos(radians(wp.lat)) * cos(radians(p.lat))
        * power(sin(radians(p.lng - wp.lng) / 2.0), 2),
      p.id
    limit 1
  ) as picked
  on conflict (user_id, place_id) do nothing;

  return jsonb_build_object('remaining', remaining, 'challenge_id', ch.id);
end;
$$;
