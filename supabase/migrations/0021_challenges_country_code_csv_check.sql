-- =============================================================================
-- 0021_challenges_country_code_csv_check.sql
-- ALREADY APPLIED ON PROD yzmbxxgesnbsqygzgdky (Postgres 17).
-- History version 20261007112721, name challenges_country_code_csv_check.
-- Do not re-apply.
--
-- challenges.country_code stays text. A value is one code or a
-- comma-separated list (CZ,AT or CZ,AT,PL). Spaces are ignored and the
-- check is case-insensitive. Allowed codes: CZ, SK, AT, DE, PL.
-- Null stays allowed.
-- =============================================================================

ALTER TABLE public.challenges DROP CONSTRAINT IF EXISTS challenges_country_code_check;

ALTER TABLE public.challenges ADD CONSTRAINT challenges_country_code_check CHECK (
  country_code IS NULL
  OR upper(replace(btrim(country_code), ' ', '')) ~ '^(CZ|SK|AT|DE|PL)(,(CZ|SK|AT|DE|PL))*$'
);
