-- Catalog country filter (CZ / SK / AT / DE / PL).
--
-- `region` stays a free-text display string (Pálava, Beskydy, Vysočina, …).
-- Filter chips use this new `country_code` column, not `region`.
--
-- access_mode: already present from 0001_init as
--   text not null check (access_mode in ('open', 'story'))
-- Live catalog (2026-09-16): every row is access_mode='open'.
-- Five rows are status='archived' (ended seasons / period_state), not story
-- challenges. Catalog RLS and the client only expose status='published', so
-- treating archived as Story would hide those rows and still leave the Story
-- chip empty for published challenges. We keep access_mode as the sole mode
-- source and do not backfill archived → story. CMS authors set story
-- explicitly when a challenge uses sequential waypoint unlock.

alter table public.challenges
  add column if not exists country_code text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'challenges_country_code_check'
  ) then
    alter table public.challenges
      add constraint challenges_country_code_check
      check (
        country_code is null
        or country_code in ('CZ', 'SK', 'AT', 'DE', 'PL')
      );
  end if;
end $$;

-- Obvious Czech place-name / country labels. Leave everything else null.
update public.challenges
set country_code = 'CZ'
where country_code is null
  and region is not null
  and (
    region ~* '(česko|cesko|morava|pálava|palava|beskydy|vysočina|vysocina|orlick|středohoří|stredohori|bohemia|czechia|prague|praha)'
  );

update public.challenges
set country_code = 'SK'
where country_code is null
  and region is not null
  and region ~* '(slovensko|slovakia|tatry|liptov)';

update public.challenges
set country_code = 'AT'
where country_code is null
  and region is not null
  and region ~* '(rakousko|österreich|osterreich|austria)';

update public.challenges
set country_code = 'DE'
where country_code is null
  and region is not null
  and region ~* '(německo|nemecko|deutschland|germany|bavorsko)';

update public.challenges
set country_code = 'PL'
where country_code is null
  and region is not null
  and region ~* '(polsko|poland|polen)';
