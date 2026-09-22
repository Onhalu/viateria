-- Category for challenge-waypoint list icons.
--
-- Same four values as assets/map/pois.geojson properties.category and
-- PlaceCategory in lib/map/place_category.dart: city, nature, technical,
-- historical. The challenge list paints assets/map/icons/<category>@2x.png.
--
-- Default is historical, which is also PlaceCategory.fromWire's fallback
-- for a missing or unknown value. Backfill of the live rows is in
-- supabase/seed/waypoint_category_backfill.sql (nearest POI within 150 m,
-- then a folded-name fallback).

alter table public.waypoints
  add column if not exists category text not null default 'historical';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'waypoints_category_check'
  ) then
    alter table public.waypoints
      add constraint waypoints_category_check
      check (category in ('city', 'nature', 'technical', 'historical'));
  end if;
end $$;
