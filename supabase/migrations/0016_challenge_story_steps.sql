-- 0016 challenge_story_steps + i18n + story-mock seed
-- SPEC-story-mode SCHVÁLENO 2026-10-01
--
-- Already applied on prod. This file matches that schema.
-- verify_waypoint's story-step return fields are in 0017 so the
-- exclusive-promo gate from 0015 is not rolled back.
--
-- `notes` / `period_state` exist on some prod rows and are not columns
-- in this repo. The seed does not add them.

create table if not exists public.challenge_story_steps (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  sort_order integer not null check (sort_order >= 0),
  kind text not null check (kind in ('opening', 'before_waypoint', 'closing')),
  waypoint_id uuid null references public.waypoints(id) on delete cascade,
  image_url text null,
  youtube_url text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint challenge_story_steps_sort_uidx unique (challenge_id, sort_order),
  constraint challenge_story_steps_kind_waypoint_ck check (
    (kind = 'before_waypoint' and waypoint_id is not null)
    or (kind in ('opening', 'closing') and waypoint_id is null)
  )
);

create unique index if not exists challenge_story_steps_one_opening_uidx
  on public.challenge_story_steps (challenge_id) where kind = 'opening';

create unique index if not exists challenge_story_steps_one_closing_uidx
  on public.challenge_story_steps (challenge_id) where kind = 'closing';

create unique index if not exists challenge_story_steps_one_before_wp_uidx
  on public.challenge_story_steps (waypoint_id) where kind = 'before_waypoint' and waypoint_id is not null;

create table if not exists public.challenge_story_step_i18n (
  story_step_id uuid not null references public.challenge_story_steps(id) on delete cascade,
  locale text not null check (locale in ('cs', 'en', 'de')),
  title text not null,
  body text not null default '',
  primary key (story_step_id, locale)
);

create or replace function public.challenge_story_step_waypoint_same_challenge()
returns trigger
language plpgsql
as $$
begin
  if new.waypoint_id is null then
    return new;
  end if;
  if not exists (
    select 1 from public.waypoints w
    where w.id = new.waypoint_id and w.challenge_id = new.challenge_id
  ) then
    raise exception 'story step waypoint must belong to same challenge';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_challenge_story_step_waypoint on public.challenge_story_steps;
create trigger trg_challenge_story_step_waypoint
  before insert or update of waypoint_id, challenge_id
  on public.challenge_story_steps
  for each row execute function public.challenge_story_step_waypoint_same_challenge();

alter table public.challenge_story_steps enable row level security;
alter table public.challenge_story_step_i18n enable row level security;

drop policy if exists challenge_story_steps_select on public.challenge_story_steps;
create policy challenge_story_steps_select on public.challenge_story_steps
  for select to authenticated
  using (private.challenge_readable(challenge_id));

drop policy if exists challenge_story_step_i18n_select on public.challenge_story_step_i18n;
create policy challenge_story_step_i18n_select on public.challenge_story_step_i18n
  for select to authenticated
  using (
    exists (
      select 1 from public.challenge_story_steps s
      where s.id = story_step_id
        and private.challenge_readable(s.challenge_id)
    )
  );

comment on table public.challenge_story_steps is
  'Story-mode narrative steps: opening, before_waypoint (unlocks that stop), closing.';

-- ---- mock seed: story-mock -------------------------------------------------
-- Place ids are the production catalog. A fresh local database without
-- those places skips the seed; the tables above still apply.
do $$
declare
  cid uuid := 'c0ffee00-0000-4000-8000-000000000010';
  w0 uuid := 'c0ffee00-0000-4000-8000-000000000011';
  w1 uuid := 'c0ffee00-0000-4000-8000-000000000012';
  w2 uuid := 'c0ffee00-0000-4000-8000-000000000013';
  s_open uuid := 'c0ffee00-0000-4000-8000-000000000014';
  s_b0 uuid := 'c0ffee00-0000-4000-8000-000000000015';
  s_b1 uuid := 'c0ffee00-0000-4000-8000-000000000016';
  s_b2 uuid := 'c0ffee00-0000-4000-8000-000000000017';
  s_close uuid := 'c0ffee00-0000-4000-8000-000000000018';
  p0 uuid := '567b3001-7dca-4d66-bbb3-0e97a6a33c13'; -- Adršpašsko-teplické skály
  p1 uuid := '02faca93-0e83-4d23-b38a-83914bbf6e57'; -- Propast Macocha
  p2 uuid := '09bb8303-30da-4b3e-8809-bc4344df11dd'; -- Arcibiskupský zámek Kroměříž
begin
  if not exists (select 1 from public.places where id = p0)
     or not exists (select 1 from public.places where id = p1)
     or not exists (select 1 from public.places where id = p2) then
    raise notice 'story-mock seed skipped: catalog places not present';
    return;
  end if;

  insert into public.challenges (
    id, slug, access_mode, pricing_type, price_cents, currency, status,
    region, country_code, difficulty, is_promo
  ) values (
    cid, 'story-mock', 'story', 'free', 0, 'czk', 'published',
    'CZ-test', 'CZ', 'easy', false
  ) on conflict (id) do update set
    access_mode = excluded.access_mode,
    status = excluded.status,
    pricing_type = excluded.pricing_type,
    updated_at = now();

  update public.challenges set slug = 'story-mock'
  where id = cid;

  insert into public.challenge_i18n (challenge_id, locale, title, description)
  values
    (cid, 'cs', 'Příběhová výzva (mock)', 'Testovací lineární výprava s fog-of-war mapou a story kapitolami.'),
    (cid, 'en', 'Story challenge (mock)', 'Test linear expedition with fog-of-war map and story chapters.'),
    (cid, 'de', 'Story-Challenge (Mock)', 'Test einer linearen Expedition mit Fog-of-War und Story-Kapiteln.')
  on conflict (challenge_id, locale) do update set
    title = excluded.title,
    description = excluded.description;

  insert into public.waypoints (id, challenge_id, sort_order, lat, lng, elevation_m, verify_method, category, place_id)
  values
    (w0, cid, 0, 50.611389, 16.115, 0, 'photo', 'nature', p0),
    (w1, cid, 1, 49.3732361, 16.7298156, 0, 'photo', 'nature', p1),
    (w2, cid, 2, 49.300278, 17.393056, 0, 'photo', 'historical', p2)
  on conflict (id) do update set
    place_id = excluded.place_id,
    sort_order = excluded.sort_order,
    lat = excluded.lat,
    lng = excluded.lng,
    category = excluded.category;

  insert into public.waypoint_i18n (waypoint_id, locale, title, description, hint)
  values
    (w0, 'cs', 'Adršpašské skály', 'První zastávka mock story.', ''),
    (w0, 'en', 'Adršpach rocks', 'First mock story stop.', ''),
    (w1, 'cs', 'Propast Macocha', 'Druhá zastávka.', ''),
    (w1, 'en', 'Macocha abyss', 'Second stop.', ''),
    (w2, 'cs', 'Zámek Kroměříž', 'Třetí zastávka.', ''),
    (w2, 'en', 'Kroměříž castle', 'Third stop.', '')
  on conflict (waypoint_id, locale) do update set
    title = excluded.title,
    description = excluded.description;

  insert into public.challenge_story_steps (id, challenge_id, sort_order, kind, waypoint_id, image_url, youtube_url)
  values
    (s_open, cid, 0, 'opening', null, null, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
    (s_b0, cid, 1, 'before_waypoint', w0, null, null),
    (s_b1, cid, 2, 'before_waypoint', w1, 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800', null),
    (s_b2, cid, 3, 'before_waypoint', w2, null, null),
    (s_close, cid, 4, 'closing', null, null, null)
  on conflict (id) do update set
    sort_order = excluded.sort_order,
    kind = excluded.kind,
    waypoint_id = excluded.waypoint_id,
    youtube_url = excluded.youtube_url,
    image_url = excluded.image_url,
    updated_at = now();

  insert into public.challenge_story_step_i18n (story_step_id, locale, title, body)
  values
    (s_open, 'cs', 'Úvod výzvy', 'Vítej v příběhové výpravě. Nejdřív si pusť video, pak vyraz na první místo.'),
    (s_open, 'en', 'Challenge intro', 'Welcome to the story expedition. Watch the video, then head to the first stop.'),
    (s_b0, 'cs', 'Před Adršpachem', 'Mlha se zvedá. Ověř první skálu, ať se otevře další kapitola.'),
    (s_b0, 'en', 'Before Adršpach', 'The fog lifts. Verify the first rock to open the next chapter.'),
    (s_b1, 'cs', 'Cesta k Macoše', 'Po skále přichází propast. Přečti si stopy a vyraz dál.'),
    (s_b1, 'en', 'Road to Macocha', 'After the rocks comes the abyss. Read the clues and continue.'),
    (s_b2, 'cs', 'K zámku', 'Poslední stopa vede do Kroměříže.'),
    (s_b2, 'en', 'To the castle', 'The last clue leads to Kroměříž.'),
    (s_close, 'cs', 'Závěr výzvy', 'Hotovo. Příběh končí — diplom čeká.'),
    (s_close, 'en', 'Challenge outro', 'Done. The story ends — your diploma awaits.')
  on conflict (story_step_id, locale) do update set
    title = excluded.title,
    body = excluded.body;
end $$;
