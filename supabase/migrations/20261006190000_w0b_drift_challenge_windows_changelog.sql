-- Drift mirror of prod history that was never committed.
-- Mirrors prod migration 20260908152617 challenge_windows_and_changelog
-- (and the later W migrations that read starts_at, ends_at, period_state, notes).
-- Idempotent: ADD COLUMN IF NOT EXISTS / CREATE TABLE IF NOT EXISTS.
-- A no-op on prod, where these objects already exist.
-- MUST NEVER be applied to prod (yzmbxxgesnbsqygzgdky).
-- repair/apply is Ask first.

alter table public.challenges
  add column if not exists starts_at timestamptz,
  add column if not exists ends_at timestamptz,
  add column if not exists diploma_price_cents integer not null default 0 check (diploma_price_cents >= 0),
  add column if not exists medal_price_cents integer check (medal_price_cents is null or medal_price_cents >= 0),
  add column if not exists period_state text not null default 'active' check (period_state in ('active', 'ended')),
  add column if not exists notes text;

create table if not exists public.challenge_changes (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  occurred_at timestamptz not null default now(),
  kind text not null check (kind in ('created', 'published', 'ended', 'updated', 'note')),
  summary text not null
);

create index if not exists challenge_changes_challenge_idx
  on public.challenge_changes (challenge_id, occurred_at);

alter table public.challenge_changes enable row level security;

drop policy if exists "challenge changes of published challenges" on public.challenge_changes;
create policy "challenge changes of published challenges"
  on public.challenge_changes for select to authenticated
  using (
    exists (
      select 1 from public.challenges c
      where c.id = challenge_id and c.status = 'published'
    )
  );
