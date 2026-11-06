-- Drift fix A2 (optional, before W1). Not required for the chain to apply;
-- gives local/staging parity with prod for the challenge cover bucket.
-- Prod got it from 20260918165359 challenge_covers_bucket +
-- 20260918170026 challenge_covers_lock_writes (prod history only, not in repo).
-- Net effect of those two: bucket + public read policy (temporary anon write
-- policies were created and dropped again). No-op on prod (verified 2026-11-06).

do $$
begin
  if to_regclass('storage.buckets') is null then
    raise notice 'storage schema missing, skipping challenge-covers bucket';
    return;
  end if;

  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values (
    'challenge-covers',
    'challenge-covers',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
  )
  on conflict (id) do nothing;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'challenge_covers_public_read'
  ) then
    create policy "challenge_covers_public_read"
      on storage.objects for select
      to public
      using (bucket_id = 'challenge-covers');
  end if;
end;
$$;
