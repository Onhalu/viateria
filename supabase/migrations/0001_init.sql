-- Viateria SPEC v1 schema
-- users, challenges, waypoints, progress, promo_stripes, purchases
-- Content statuses: draft | published | archived

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  locale text not null default 'cs' check (locale in ('cs', 'en', 'de')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  access_mode text not null check (access_mode in ('open', 'story')),
  pricing_type text not null check (pricing_type in ('free', 'paid')),
  price_cents integer not null default 0 check (price_cents >= 0),
  currency text not null default 'eur',
  stripe_price_id text,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  cover_image_url text,
  region text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.challenge_i18n (
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  locale text not null check (locale in ('cs', 'en', 'de')),
  title text not null,
  description text not null default '',
  diploma_headline text,
  diploma_body text,
  primary key (challenge_id, locale)
);

create table if not exists public.waypoints (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  sort_order integer not null check (sort_order >= 0),
  lat double precision not null,
  lng double precision not null,
  elevation_m double precision not null default 0,
  verify_method text not null default 'photo' check (verify_method = 'photo'),
  unique (challenge_id, sort_order)
);

create table if not exists public.waypoint_i18n (
  waypoint_id uuid not null references public.waypoints (id) on delete cascade,
  locale text not null check (locale in ('cs', 'en', 'de')),
  title text not null,
  description text not null default '',
  hint text,
  primary key (waypoint_id, locale)
);

create table if not exists public.challenge_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  status text not null default 'in_progress' check (status in ('in_progress', 'completed')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (user_id, challenge_id)
);

create table if not exists public.waypoint_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  waypoint_id uuid not null references public.waypoints (id) on delete cascade,
  photo_path text not null,
  completed_at timestamptz not null default now(),
  unique (user_id, waypoint_id)
);

create table if not exists public.promo_stripes (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  sort_order integer not null default 0,
  image_url text,
  link_url text,
  challenge_id uuid references public.challenges (id) on delete set null,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.promo_stripe_i18n (
  promo_stripe_id uuid not null references public.promo_stripes (id) on delete cascade,
  locale text not null check (locale in ('cs', 'en', 'de')),
  title text not null,
  subtitle text,
  cta_label text,
  primary key (promo_stripe_id, locale)
);

create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  stripe_checkout_session_id text unique,
  stripe_payment_intent_id text,
  status text not null default 'pending' check (status in ('pending', 'paid', 'failed', 'refunded')),
  amount_cents integer not null,
  currency text not null default 'eur',
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  unique (user_id, challenge_id)
);

create index if not exists challenges_status_idx on public.challenges (status);
create index if not exists waypoints_challenge_idx on public.waypoints (challenge_id, sort_order);
create index if not exists promo_stripes_status_idx on public.promo_stripes (status, sort_order);
create index if not exists purchases_user_idx on public.purchases (user_id, status);
create index if not exists waypoint_progress_user_idx on public.waypoint_progress (user_id);

-- Profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, locale)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data ->> 'locale', 'cs')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- VerifyWaypoint v1: live photo path required; no GPS.
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

  return jsonb_build_object('remaining', remaining, 'challenge_id', ch.id);
end;
$$;

grant execute on function public.verify_waypoint(uuid, text) to authenticated;

alter table public.profiles enable row level security;
alter table public.challenges enable row level security;
alter table public.challenge_i18n enable row level security;
alter table public.waypoints enable row level security;
alter table public.waypoint_i18n enable row level security;
alter table public.challenge_progress enable row level security;
alter table public.waypoint_progress enable row level security;
alter table public.promo_stripes enable row level security;
alter table public.promo_stripe_i18n enable row level security;
alter table public.purchases enable row level security;

-- Catalog: published only for authenticated readers. Writes via service role / dashboard.
create policy "published challenges are readable"
  on public.challenges for select to authenticated
  using (status = 'published');

create policy "i18n of published challenges"
  on public.challenge_i18n for select to authenticated
  using (
    exists (
      select 1 from public.challenges c
      where c.id = challenge_id and c.status = 'published'
    )
  );

create policy "waypoints of published challenges"
  on public.waypoints for select to authenticated
  using (
    exists (
      select 1 from public.challenges c
      where c.id = challenge_id and c.status = 'published'
    )
  );

create policy "waypoint i18n of published challenges"
  on public.waypoint_i18n for select to authenticated
  using (
    exists (
      select 1
      from public.waypoints w
      join public.challenges c on c.id = w.challenge_id
      where w.id = waypoint_id and c.status = 'published'
    )
  );

create policy "published promos are readable"
  on public.promo_stripes for select to authenticated
  using (status = 'published');

create policy "promo i18n of published stripes"
  on public.promo_stripe_i18n for select to authenticated
  using (
    exists (
      select 1 from public.promo_stripes p
      where p.id = promo_stripe_id and p.status = 'published'
    )
  );

create policy "profiles are self-readable"
  on public.profiles for select to authenticated
  using (id = auth.uid());

create policy "profiles are self-updatable"
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "own progress readable"
  on public.challenge_progress for select to authenticated
  using (user_id = auth.uid());

create policy "own waypoint progress readable"
  on public.waypoint_progress for select to authenticated
  using (user_id = auth.uid());

create policy "own purchases readable"
  on public.purchases for select to authenticated
  using (user_id = auth.uid());

-- Storage bucket for VerifyWaypoint photos
insert into storage.buckets (id, name, public)
values ('waypoint-photos', 'waypoint-photos', false)
on conflict (id) do nothing;

create policy "users upload own waypoint photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'waypoint-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "users read own waypoint photos"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'waypoint-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
