-- Master place catalog for the map.
--
-- Mirrors production public.places, including description, region, and
-- place_type. Idempotent: creating or altering the table does not delete
-- rows. Client access is public SELECT only (places_select_public).

create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  lat double precision not null,
  lng double precision not null,
  elevation_m double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  description text,
  region text,
  place_type text
);

alter table public.places add column if not exists description text;
alter table public.places add column if not exists region text;
alter table public.places add column if not exists place_type text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'places_category_check'
      and conrelid = 'public.places'::regclass
  ) then
    alter table public.places
      add constraint places_category_check
      check (category in ('city', 'nature', 'technical', 'historical'));
  end if;
end $$;

create index if not exists places_category_idx on public.places (category);
create index if not exists places_name_idx on public.places (name);
create index if not exists places_coords_idx on public.places (lat, lng);

comment on table public.places is
  'Master place catalog; challenges map to these via place_id later.';
comment on column public.places.description is
  'Short place description from master catalog';
comment on column public.places.region is
  'Country/region code (cz, at, ...)';
comment on column public.places.place_type is
  'Fine-grained type (hrad, zámek, hora, ...)';

alter table public.places enable row level security;

drop policy if exists places_select_public on public.places;
create policy places_select_public
  on public.places
  for select
  to anon, authenticated
  using (true);

grant select on table public.places to anon, authenticated;
