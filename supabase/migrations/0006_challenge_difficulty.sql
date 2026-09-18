-- Catalog difficulty filter (easy / normal / hard).
--
-- CMS-authored. Nullable on purpose: do not backfill or invent values.
-- Catalog cards hide the label when null; a selected difficulty chip
-- excludes those rows.

alter table public.challenges
  add column if not exists difficulty text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'challenges_difficulty_check'
  ) then
    alter table public.challenges
      add constraint challenges_difficulty_check
      check (
        difficulty is null
        or difficulty in ('easy', 'normal', 'hard')
      );
  end if;
end $$;
