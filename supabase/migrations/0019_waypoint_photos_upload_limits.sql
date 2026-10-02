-- Harden uploads to the private bucket waypoint-photos.
--
-- Apply from the Supabase SQL editor (or `supabase db push`) only after
-- an explicit OK. Do not run this against production from an agent, and
-- do not merge until that OK.
--
-- Sets file_size_limit and allowed_mime_types only. Does not change
-- bucket visibility, storage.objects policies, the own-folder select,
-- or is_shared_verification_photo. Existing objects stay as they are;
-- the limits apply to later uploads.
--
-- file_size_limit is bytes: 8388608 = 8 * 1024 * 1024 (8 MiB).
-- Allowed types must stay aligned with Flutter
-- (lib/domain/photo_verify.dart):
--   image/jpeg  — live camera (imageQuality 85, maxWidth 1920) and .jpg
--   image/png   — .png
--   image/webp  — .webp
-- The client rejects any other content type, an empty body, or a body
-- larger than 8388608 bytes before the storage request.

do $$
begin
  update storage.buckets
  set
    file_size_limit = 8388608,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']::text[],
    updated_at = now()
  where id = 'waypoint-photos';

  if not found then
    raise exception 'storage.buckets row waypoint-photos is missing (0001_init.sql)';
  end if;
end
$$;
