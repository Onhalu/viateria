-- Rollback of 20261106114000 only.
-- Apply after 20261106120300 has been rolled back (that file tightens
-- diploma grants). This file drops the catalog added by 114000.

drop policy if exists vandery_plus_user_diplomas_select_own
  on public.vandery_plus_user_diplomas;
drop policy if exists vandery_plus_diplomas_select_authenticated
  on public.vandery_plus_diplomas;

drop table if exists public.vandery_plus_user_diplomas;
drop table if exists public.vandery_plus_diplomas;
