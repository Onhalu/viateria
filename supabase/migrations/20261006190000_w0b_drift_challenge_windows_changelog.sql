-- Drift fix A1 (before W1 20261006190001).
-- Recreates objects that prod got from migrations that exist in prod history
-- (supabase_migrations.schema_migrations) but were never committed to the repo:
--   20260908152617 challenge_windows_and_changelog
--   20260924094759 places_add_description_region_type
-- Every statement is idempotent and a no-op on prod (columns, table, index,
-- policy already exist there with these exact names/definitions, verified
-- read-only 2026-11-06). Constraint names match prod.

alter table public.challenges
  add column if not exists starts_at timestamptz,
  add column if not exists ends_at timestamptz,
  add column if not exists diploma_price_cents integer not null default 0
    constraint challenges_diploma_price_cents_check check (diploma_price_cents >= 0),
  add column if not exists medal_price_cents integer
    constraint challenges_medal_price_cents_check check (medal_price_cents is null or medal_price_cents >= 0),
  add column if not exists period_state text not null default 'active'
    constraint challenges_period_state_check check (period_state in ('active', 'ended')),
  add column if not exists notes text;

create table if not exists public.challenge_changes (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  occurred_at timestamptz not null default now(),
  kind text not null
    constraint challenge_changes_kind_check
    check (kind in ('created', 'published', 'ended', 'updated', 'note')),
  summary text not null
);

create index if not exists challenge_changes_challenge_idx
  on public.challenge_changes (challenge_id, occurred_at);

alter table public.challenge_changes enable row level security;

-- Final prod form (after 20260918174334 anon_read_published_catalog).
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'challenge_changes'
      and policyname = 'challenge changes of published challenges'
  ) then
    create policy "challenge changes of published challenges"
      on public.challenge_changes for select
      to anon, authenticated
      using (exists (
        select 1 from public.challenges c
        where c.id = challenge_changes.challenge_id and c.status = 'published'
      ));
  end if;
end;
$$;

alter table public.places
  add column if not exists description text,
  add column if not exists region text,
  add column if not exists place_type text;

comment on column public.places.description is 'Short place description from master catalog';
comment on column public.places.region is 'Country/region code (cz, at, ...)';
comment on column public.places.place_type is 'Fine-grained type (hrad, zámek, hora, ...)';
