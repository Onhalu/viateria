-- Community gallery on the challenge screen.
--
-- waypoint_progress RLS only lets a user read their own rows, and
-- waypoint-photos is a private bucket limited to the owner's folder.
-- The gallery needs every user's verification photo for this challenge's
-- waypoints, without opening the rest of progress (user_id, GPS sentinels)
-- or the rest of the bucket.
--
-- GPS completions store a sentinel path `{userId}/gps/{challengeId}/{waypointId}`
-- (see VerifyProximity.gpsPhotoPath). Those rows are not image objects.
-- Keep that exclusion aligned with displayablePhotoPath in
-- lib/domain/challenge_photos.dart.

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
  and p.photo_path is not null
  and length(btrim(p.photo_path)) > 0
  and p.photo_path not like '%/gps/%';

comment on view public.challenge_waypoint_photos is
  'Verification photos for published challenge waypoints, all users. Omits user_id and GPS sentinel paths. security_invoker is off so own-row waypoint_progress RLS does not hide other people.';

revoke all on table public.challenge_waypoint_photos from public;
revoke all on table public.challenge_waypoint_photos from anon;
revoke all on table public.challenge_waypoint_photos from authenticated;
grant select on table public.challenge_waypoint_photos to authenticated;

-- Storage policies run as the caller, so a direct join to waypoint_progress
-- would be filtered by own-row RLS. This definer reads the same published,
-- non-GPS photo paths the view exposes.
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
      and p.photo_path is not null
      and length(btrim(p.photo_path)) > 0
      and p.photo_path not like '%/gps/%'
  );
$$;

revoke all on function public.is_shared_verification_photo(text) from public;
revoke all on function public.is_shared_verification_photo(text) from anon;
revoke all on function public.is_shared_verification_photo(text) from authenticated;
grant execute on function public.is_shared_verification_photo(text) to authenticated;

create index if not exists waypoint_progress_photo_path_idx
  on public.waypoint_progress (photo_path);

-- Own-folder select stays in 0001_init.sql. This adds read of objects that
-- are recorded as another user's verification photo. It does not allow
-- listing or downloading arbitrary bucket keys.
drop policy if exists "authenticated read shared verification photos"
  on storage.objects;

create policy "authenticated read shared verification photos"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'waypoint-photos'
    and public.is_shared_verification_photo(name)
  );
