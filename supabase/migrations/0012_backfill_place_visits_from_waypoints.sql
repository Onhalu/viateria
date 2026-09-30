-- Backfill place_visits from waypoint_progress for verifies that ran
-- before verify_waypoint also wrote the nearest catalog place (≤50 m).
-- Idempotent: ON CONFLICT (user_id, place_id) DO NOTHING.
-- visited_at prefers the original waypoint completed_at.
--
-- Already applied on prod yzmbxxgesnbsqygzgdky as migration
-- backfill_place_visits_from_waypoints (20260930091807). Safe to re-run.

insert into public.place_visits (user_id, place_id, source, visited_at)
select
  wp.user_id,
  picked.place_id,
  'verify',
  coalesce(wp.completed_at, now())
from public.waypoint_progress wp
join public.waypoints w on w.id = wp.waypoint_id
cross join lateral (
  select p.id as place_id
  from public.places p
  where (
    6371000.0 * 2.0 * asin(
      least(
        1.0,
        sqrt(
          power(sin(radians(p.lat - w.lat) / 2.0), 2)
          + cos(radians(w.lat)) * cos(radians(p.lat))
            * power(sin(radians(p.lng - w.lng) / 2.0), 2)
        )
      )
    )
  ) <= 50
  order by
    power(sin(radians(p.lat - w.lat) / 2.0), 2)
    + cos(radians(w.lat)) * cos(radians(p.lat))
      * power(sin(radians(p.lng - w.lng) / 2.0), 2),
    p.id
  limit 1
) as picked
on conflict (user_id, place_id) do nothing;

comment on table public.place_visits is
  'One row per user and place. Duplicates are ignored so a place scores once. Pre-leaderboard verifies are backfilled from waypoint_progress (nearest place ≤50 m, source=verify).';
