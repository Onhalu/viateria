-- Rollback of 20261106120200 only.
-- Apply after 20261106120300 is rolled back, so the public trigger functions
-- exist again. Restores the membership select policy from 113000 and the
-- default execute grant those trigger functions had before this file.

drop policy if exists vandery_plus_memberships_select_own
  on public.vandery_plus_memberships;
create policy vandery_plus_memberships_select_own
  on public.vandery_plus_memberships
  for select
  to authenticated
  using (user_id = auth.uid());

grant execute on function public.touch_vandery_plus_membership() to public;
grant execute on function public.anonymize_vandery_plus_before_profile_delete() to public;
