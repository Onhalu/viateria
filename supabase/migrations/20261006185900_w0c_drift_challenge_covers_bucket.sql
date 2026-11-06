-- Drift mirror of prod history that was never committed.
-- Mirrors prod migrations 20260918165359 challenge_covers_bucket
-- and 20260918170026 challenge_covers_lock_writes.
-- Optional prod parity for the challenge-covers bucket. Idempotent.
-- MUST NEVER be applied to prod (yzmbxxgesnbsqygzgdky).
-- repair/apply is Ask first.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'challenge-covers',
  'challenge-covers',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- public read
drop policy if exists "challenge_covers_public_read" on storage.objects;
create policy "challenge_covers_public_read"
  on storage.objects for select
  to public
  using (bucket_id = 'challenge-covers');

-- temporary anon write for bootstrap upload (removed after upload)
drop policy if exists "challenge_covers_anon_insert_tmp" on storage.objects;
create policy "challenge_covers_anon_insert_tmp"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'challenge-covers');

drop policy if exists "challenge_covers_anon_update_tmp" on storage.objects;
create policy "challenge_covers_anon_update_tmp"
  on storage.objects for update
  to anon, authenticated
  using (bucket_id = 'challenge-covers')
  with check (bucket_id = 'challenge-covers');

drop policy if exists "challenge_covers_anon_insert_tmp" on storage.objects;
drop policy if exists "challenge_covers_anon_update_tmp" on storage.objects;
