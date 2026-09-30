-- SPEC-challenge-places (SCHVÁLENO): nullable waypoints.place_id + backfill.
--
-- Places stay the only production catalog. The new column stays nullable.
-- Apply on yzmbxxgesnbsqygzgdky before the client that reads place_id.
-- 0014 is a later step: apply it only when unmatched published waypoints = 0.
--
-- Idempotent. Rows that already have place_id are left alone. The nearest
-- place within 50 m uses the same haversine as 0011 verify_waypoint and
-- 0012 place_visits backfill (earth radius 6371000 m, tie-break by place id).
--
-- Known miss (stays null here; parent CMS-fixes before 0014):
--   published waypoint 95f6584b-45be-4b57-9af8-12a10b2a2a2d
--   (Zelená Hora, challenge slug vyzva-zdarma)
--   is 55.5 m from place „Poutní kostel sv. Jana Nepomuckého na Zelené Hoře“.

alter table public.waypoints
  add column if not exists place_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'waypoints_place_id_fkey'
      and conrelid = 'public.waypoints'::regclass
  ) then
    alter table public.waypoints
      add constraint waypoints_place_id_fkey
      foreign key (place_id) references public.places (id);
  end if;
end $$;

comment on column public.waypoints.place_id is
  'Catalog place for this stop. Nullable until 0014. Map tint and verify use this id, not proximity.';

create index if not exists waypoints_place_id_idx
  on public.waypoints (place_id);

-- Nearest place ≤50 m, only where place_id is still null.
update public.waypoints as w
set place_id = picked.place_id
from (
  select w2.id as waypoint_id, nearest.place_id
  from public.waypoints w2
  cross join lateral (
    select p.id as place_id
    from public.places p
    where (
      6371000.0 * 2.0 * asin(
        least(
          1.0,
          sqrt(
            power(sin(radians(p.lat - w2.lat) / 2.0), 2)
            + cos(radians(w2.lat)) * cos(radians(p.lat))
              * power(sin(radians(p.lng - w2.lng) / 2.0), 2)
          )
        )
      )
    ) <= 50
    order by
      power(sin(radians(p.lat - w2.lat) / 2.0), 2)
      + cos(radians(w2.lat)) * cos(radians(p.lat))
        * power(sin(radians(p.lng - w2.lng) / 2.0), 2),
      p.id
    limit 1
  ) as nearest
  where w2.place_id is null
) as picked
where w.id = picked.waypoint_id
  and w.place_id is null;
