-- SPEC-promo-widget (SCHVÁLENO)
--
-- Parent applies this file. Do not run it against yzmbxxgesnbsqygzgdky
-- from an agent, and do not merge the PR until an explicit "merge".
--
-- Exclusive challenges (`challenges.is_promo`) stay out of the ordinary
-- catalog. A published promo stripe with zero `promo_assignments` rows is
-- visible to every signed-in user. Any assignment row switches that stripe
-- to OR matching (all | user | segment | locale | country).
--
-- Dashboard / service_role bypasses RLS. That is the admin path.

-- ---------------------------------------------------------------------------
-- challenges.is_promo
-- ---------------------------------------------------------------------------

alter table public.challenges
  add column if not exists is_promo boolean not null default false;

comment on column public.challenges.is_promo is
  'Exclusive promo challenge. Hidden from ordinary catalog queries. Readable only when the caller has a matching active promo stripe for this challenge.';

create index if not exists challenges_is_promo_idx
  on public.challenges (id)
  where is_promo;

-- ---------------------------------------------------------------------------
-- promo_stripes: kind + optional discount prices
-- Existing rows default to discount so a banner does not become exclusive.
-- Published stripes should point at a challenge. NOT VALID so a legacy
-- published row without challenge_id does not fail this migration; new
-- writes of status=published must set challenge_id.
-- ---------------------------------------------------------------------------

alter table public.promo_stripes
  add column if not exists kind text not null default 'discount';

alter table public.promo_stripes
  add column if not exists promo_diploma_price_cents integer;

alter table public.promo_stripes
  add column if not exists promo_medal_price_cents integer;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'promo_stripes_kind_check'
  ) then
    alter table public.promo_stripes
      add constraint promo_stripes_kind_check
      check (kind in ('exclusive', 'discount'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'promo_stripes_diploma_price_check'
  ) then
    alter table public.promo_stripes
      add constraint promo_stripes_diploma_price_check
      check (
        promo_diploma_price_cents is null
        or promo_diploma_price_cents >= 0
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'promo_stripes_medal_price_check'
  ) then
    alter table public.promo_stripes
      add constraint promo_stripes_medal_price_check
      check (
        promo_medal_price_cents is null
        or promo_medal_price_cents >= 0
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'promo_stripes_published_challenge'
  ) then
    alter table public.promo_stripes
      add constraint promo_stripes_published_challenge
      check (status <> 'published' or challenge_id is not null)
      not valid;
  end if;
end $$;

comment on column public.promo_stripes.kind is
  'exclusive: paired with challenges.is_promo. discount: challenge stays in the catalog; checkout may use promo_*_price_cents.';

comment on column public.promo_stripes.promo_diploma_price_cents is
  'Optional diploma price while this discount stripe is active. Null keeps the challenge diploma price.';

comment on column public.promo_stripes.promo_medal_price_cents is
  'Optional medal+diploma price while this discount stripe is active. Null keeps the challenge medal price.';

create index if not exists promo_stripes_discount_challenge_idx
  on public.promo_stripes (challenge_id)
  where kind = 'discount' and status = 'published';

-- ---------------------------------------------------------------------------
-- Audience
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists country_code text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_country_code_check'
  ) then
    alter table public.profiles
      add constraint profiles_country_code_check
      check (country_code is null or country_code ~ '^[A-Z]{2}$');
  end if;
end $$;

comment on column public.profiles.country_code is
  'Nullable ISO 3166-1 alpha-2 for promo country targeting. Not the catalog chip list.';

create table if not exists public.promo_segments (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.promo_segment_members (
  segment_id uuid not null references public.promo_segments (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (segment_id, user_id)
);

create index if not exists promo_segment_members_user_idx
  on public.promo_segment_members (user_id);

create table if not exists public.promo_assignments (
  id uuid primary key default gen_random_uuid(),
  promo_stripe_id uuid not null references public.promo_stripes (id) on delete cascade,
  target_type text not null check (target_type in ('all', 'user', 'segment', 'locale', 'country')),
  user_id uuid references public.profiles (id) on delete cascade,
  segment_id uuid references public.promo_segments (id) on delete cascade,
  locale text,
  country_code text,
  created_at timestamptz not null default now(),
  constraint promo_assignments_locale_check
    check (locale is null or locale in ('cs', 'en', 'de')),
  constraint promo_assignments_country_check
    check (country_code is null or country_code ~ '^[A-Z]{2}$'),
  constraint promo_assignments_shape check (
    (
      target_type = 'all'
      and user_id is null
      and segment_id is null
      and locale is null
      and country_code is null
    )
    or (
      target_type = 'user'
      and user_id is not null
      and segment_id is null
      and locale is null
      and country_code is null
    )
    or (
      target_type = 'segment'
      and segment_id is not null
      and user_id is null
      and locale is null
      and country_code is null
    )
    or (
      target_type = 'locale'
      and locale is not null
      and user_id is null
      and segment_id is null
      and country_code is null
    )
    or (
      target_type = 'country'
      and country_code is not null
      and user_id is null
      and segment_id is null
      and locale is null
    )
  )
);

create index if not exists promo_assignments_stripe_idx
  on public.promo_assignments (promo_stripe_id);

create unique index if not exists promo_assignments_all_uidx
  on public.promo_assignments (promo_stripe_id)
  where target_type = 'all';

create unique index if not exists promo_assignments_user_uidx
  on public.promo_assignments (promo_stripe_id, user_id)
  where target_type = 'user';

create unique index if not exists promo_assignments_segment_uidx
  on public.promo_assignments (promo_stripe_id, segment_id)
  where target_type = 'segment';

create unique index if not exists promo_assignments_locale_uidx
  on public.promo_assignments (promo_stripe_id, locale)
  where target_type = 'locale';

create unique index if not exists promo_assignments_country_uidx
  on public.promo_assignments (promo_stripe_id, country_code)
  where target_type = 'country';

alter table public.promo_segments enable row level security;
alter table public.promo_segment_members enable row level security;
alter table public.promo_assignments enable row level security;

-- No client policies. Membership is not readable through the Data API.
-- service_role (dashboard) bypasses RLS.

-- ---------------------------------------------------------------------------
-- Visibility helpers live in an unexposed schema. security definer so the
-- checks can read assignments without opening those tables to the client,
-- and without recursing into promo_stripes RLS.
-- ---------------------------------------------------------------------------

create schema if not exists private;

revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

create or replace function private.user_matches_promo(p_stripe_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    not exists (
      select 1
      from public.promo_assignments a
      where a.promo_stripe_id = p_stripe_id
    )
    or exists (
      select 1
      from public.promo_assignments a
      left join public.profiles me on me.id = auth.uid()
      where a.promo_stripe_id = p_stripe_id
        and (
          a.target_type = 'all'
          or (a.target_type = 'user' and a.user_id = auth.uid())
          or (
            a.target_type = 'segment'
            and exists (
              select 1
              from public.promo_segment_members m
              where m.segment_id = a.segment_id
                and m.user_id = auth.uid()
            )
          )
          or (
            a.target_type = 'locale'
            and me.locale is not null
            and a.locale = me.locale
          )
          or (
            a.target_type = 'country'
            and me.country_code is not null
            and upper(a.country_code) = upper(me.country_code)
          )
        )
    );
$$;

create or replace function private.user_has_promo_challenge(p_challenge_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.promo_stripes s
    where s.challenge_id = p_challenge_id
      and s.status = 'published'
      and (s.starts_at is null or s.starts_at <= now())
      and (s.ends_at is null or s.ends_at >= now())
      and private.user_matches_promo(s.id)
  );
$$;

create or replace function private.challenge_readable(p_challenge_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.challenges c
    where c.id = p_challenge_id
      and c.status = 'published'
      and (
        c.is_promo = false
        or private.user_has_promo_challenge(c.id)
      )
  );
$$;

revoke all on function private.user_matches_promo(uuid) from public;
revoke all on function private.user_has_promo_challenge(uuid) from public;
revoke all on function private.challenge_readable(uuid) from public;
grant execute on function private.user_matches_promo(uuid) to authenticated, service_role;
grant execute on function private.user_has_promo_challenge(uuid) to authenticated, service_role;
grant execute on function private.challenge_readable(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

drop policy if exists "published challenges are readable" on public.challenges;
create policy "published challenges are readable"
  on public.challenges for select to authenticated
  using (private.challenge_readable(id));

drop policy if exists "i18n of published challenges" on public.challenge_i18n;
create policy "i18n of published challenges"
  on public.challenge_i18n for select to authenticated
  using (private.challenge_readable(challenge_id));

drop policy if exists "waypoints of published challenges" on public.waypoints;
create policy "waypoints of published challenges"
  on public.waypoints for select to authenticated
  using (private.challenge_readable(challenge_id));

drop policy if exists "waypoint i18n of published challenges" on public.waypoint_i18n;
create policy "waypoint i18n of published challenges"
  on public.waypoint_i18n for select to authenticated
  using (
    exists (
      select 1
      from public.waypoints w
      where w.id = waypoint_id
        and private.challenge_readable(w.challenge_id)
    )
  );

drop policy if exists "published promos are readable" on public.promo_stripes;
create policy "published promos are readable"
  on public.promo_stripes for select to authenticated
  using (
    status = 'published'
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at >= now())
    and private.user_matches_promo(id)
  );

drop policy if exists "promo i18n of published stripes" on public.promo_stripe_i18n;
create policy "promo i18n of published stripes"
  on public.promo_stripe_i18n for select to authenticated
  using (
    exists (
      select 1
      from public.promo_stripes p
      where p.id = promo_stripe_id
    )
  );

-- Community gallery stays on published challenges, and exclusive rows only
-- for a caller who currently matches that challenge's promo.
create or replace view public.challenge_waypoint_photos
with (security_invoker = false, security_barrier = true) as
select
  w.challenge_id,
  p.waypoint_id,
  p.photo_path,
  p.completed_at
from public.waypoint_progress p
join public.waypoints w on w.id = p.waypoint_id
join public.challenges c on c.id = w.challenge_id
where c.status = 'published'
  and (
    c.is_promo = false
    or private.user_has_promo_challenge(c.id)
  )
  and p.photo_path is not null
  and length(btrim(p.photo_path)) > 0
  and p.photo_path not like '%/gps/%';

create or replace function public.is_shared_verification_photo(object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.waypoint_progress p
    join public.waypoints w on w.id = p.waypoint_id
    join public.challenges c on c.id = w.challenge_id
    where p.photo_path = object_name
      and c.status = 'published'
      and (
        c.is_promo = false
        or private.user_has_promo_challenge(c.id)
      )
      and p.photo_path is not null
      and length(btrim(p.photo_path)) > 0
      and p.photo_path not like '%/gps/%'
  );
$$;

revoke all on function public.is_shared_verification_photo(text) from public;
revoke all on function public.is_shared_verification_photo(text) from anon;
grant execute on function public.is_shared_verification_photo(text) to authenticated;

-- ---------------------------------------------------------------------------
-- list_my_promos: published + time window + audience.
-- 0 assignments = everyone; otherwise OR across assignment rows.
-- ---------------------------------------------------------------------------

create or replace function public.list_my_promos()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(
    (
      select jsonb_agg(q.payload order by q.sort_order, q.id)
      from (
        select
          s.sort_order,
          s.id,
          jsonb_build_object(
            'id', s.id,
            'status', s.status,
            'sort_order', s.sort_order,
            'image_url', s.image_url,
            'link_url', s.link_url,
            'challenge_id', s.challenge_id,
            'starts_at', s.starts_at,
            'ends_at', s.ends_at,
            'kind', s.kind,
            'promo_diploma_price_cents', s.promo_diploma_price_cents,
            'promo_medal_price_cents', s.promo_medal_price_cents,
            'promo_stripe_i18n', coalesce(
              (
                select jsonb_agg(
                  jsonb_build_object(
                    'locale', i.locale,
                    'title', i.title,
                    'subtitle', i.subtitle,
                    'cta_label', i.cta_label
                  )
                  order by i.locale
                )
                from public.promo_stripe_i18n i
                where i.promo_stripe_id = s.id
              ),
              '[]'::jsonb
            )
          ) as payload
        from public.promo_stripes s
        where s.status = 'published'
          and (s.starts_at is null or s.starts_at <= now())
          and (s.ends_at is null or s.ends_at >= now())
          and private.user_matches_promo(s.id)
      ) q
    ),
    '[]'::jsonb
  );
$$;

comment on function public.list_my_promos() is
  'Published promo stripes in the current time window that match the caller. Zero assignment rows means everyone.';

revoke all on function public.list_my_promos() from public;
revoke all on function public.list_my_promos() from anon;
grant execute on function public.list_my_promos() to authenticated;

-- Exclusive challenges are not verifiable unless the caller matches a live
-- promo for that challenge. Same error as an unpublished row.
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

  if ch.is_promo and not private.user_has_promo_challenge(ch.id) then
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

-- ---------------------------------------------------------------------------
-- Mock seed (Test A). Applies when this migration is applied.
-- Visible to everyone: zero promo_assignments on the stripe.
-- Slug promo-mock, is_promo, published, ends_at = now() + 14 days.
--
-- Test B (do not run here): limit that stripe to Ondřej.
--   select id, display_name, email
--   from public.profiles
--   where display_name ilike '%ondřej%'
--      or display_name ilike '%ondrej%'
--      or email ilike '%ondrej%';
--
--   insert into public.promo_assignments (promo_stripe_id, target_type, user_id)
--   values (
--     'c0ffee00-0000-4000-8000-000000000002',
--     'user',
--     '<ondrej-profile-uuid>'
--   );
-- After that insert, only a matching user sees the stripe. Delete the row
-- to restore Test A (everyone).
-- ---------------------------------------------------------------------------

insert into public.challenges (
  id,
  slug,
  access_mode,
  pricing_type,
  price_cents,
  diploma_price_cents,
  medal_price_cents,
  currency,
  status,
  region,
  country_code,
  is_promo
) values (
  'c0ffee00-0000-4000-8000-000000000001',
  'promo-mock',
  'open',
  'free',
  0,
  0,
  0,
  'eur',
  'published',
  'Promo',
  'CZ',
  true
)
on conflict (slug) do update
set
  status = 'published',
  is_promo = true,
  access_mode = excluded.access_mode,
  pricing_type = excluded.pricing_type;

insert into public.challenge_i18n (challenge_id, locale, title, description)
select c.id, v.locale, v.title, v.description
from public.challenges c
cross join (
  values
    ('cs', 'Promo výzva', 'Ukázková exkluzivní výzva.'),
    ('en', 'Promo challenge', 'Sample exclusive challenge.'),
    ('de', 'Promo-Challenge', 'Beispiel einer exklusiven Challenge.')
) as v(locale, title, description)
where c.slug = 'promo-mock'
on conflict (challenge_id, locale) do update
set
  title = excluded.title,
  description = excluded.description;

insert into public.promo_stripes (
  id,
  status,
  sort_order,
  challenge_id,
  kind,
  starts_at,
  ends_at
)
select
  'c0ffee00-0000-4000-8000-000000000002',
  'published',
  0,
  c.id,
  'exclusive',
  now(),
  now() + interval '14 days'
from public.challenges c
where c.slug = 'promo-mock'
on conflict (id) do update
set
  status = 'published',
  kind = 'exclusive',
  challenge_id = excluded.challenge_id,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at;

insert into public.promo_stripe_i18n (promo_stripe_id, locale, title, subtitle, cta_label)
values
  (
    'c0ffee00-0000-4000-8000-000000000002',
    'cs',
    'Promo výzva',
    'Exkluzivní trasa na čtrnáct dní.',
    'Získat výzvu'
  ),
  (
    'c0ffee00-0000-4000-8000-000000000002',
    'en',
    'Promo challenge',
    'An exclusive route for fourteen days.',
    'Get the challenge'
  ),
  (
    'c0ffee00-0000-4000-8000-000000000002',
    'de',
    'Promo-Challenge',
    'Eine exklusive Route für vierzehn Tage.',
    'Challenge holen'
  )
on conflict (promo_stripe_id, locale) do update
set
  title = excluded.title,
  subtitle = excluded.subtitle,
  cta_label = excluded.cta_label;

insert into public.promo_segments (id, slug, name)
values
  (
    'c0ffee00-0000-4000-8000-000000000011',
    'new_users',
    'Noví uživatelé'
  ),
  (
    'c0ffee00-0000-4000-8000-000000000012',
    'cz_users',
    'Uživatelé CZ'
  )
on conflict (slug) do nothing;
