-- VANDERY+ thematic diplomas (SPEC §5, module vandery-plus-rewards).
--
-- Schema only. Do not seed titles. Ondřej's P5 list is still outstanding.
-- A placeholder row would look like a real diploma, so the catalog stays empty.

create table if not exists public.vandery_plus_diplomas (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title_i18n jsonb not null default '{}'::jsonb,
  is_hidden boolean not null default false,
  unlock_rule jsonb not null default '{}'::jsonb,
  asset_ref text,
  created_at timestamptz not null default now()
);

comment on table public.vandery_plus_diplomas is
  'P5 placeholder catalog. Empty until Ondřej supplies the thematic diploma list. Do not insert production titles.';

create table if not exists public.vandery_plus_user_diplomas (
  user_id uuid not null references public.profiles (id) on delete cascade,
  diploma_id uuid not null references public.vandery_plus_diplomas (id) on delete restrict,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, diploma_id)
);

comment on table public.vandery_plus_user_diplomas is
  'Per-user diploma unlocks. Clients may select their own rows. Writes are service_role only.';

alter table public.vandery_plus_diplomas enable row level security;
alter table public.vandery_plus_user_diplomas enable row level security;

drop policy if exists vandery_plus_diplomas_select_authenticated
  on public.vandery_plus_diplomas;
create policy vandery_plus_diplomas_select_authenticated
  on public.vandery_plus_diplomas
  for select
  to authenticated
  using (true);

drop policy if exists vandery_plus_user_diplomas_select_own
  on public.vandery_plus_user_diplomas;
create policy vandery_plus_user_diplomas_select_own
  on public.vandery_plus_user_diplomas
  for select
  to authenticated
  using (user_id = auth.uid());

revoke all on table public.vandery_plus_diplomas from public, anon, authenticated;
grant select on table public.vandery_plus_diplomas to authenticated;

revoke all on table public.vandery_plus_user_diplomas from public, anon, authenticated;
grant select on table public.vandery_plus_user_diplomas to authenticated;
