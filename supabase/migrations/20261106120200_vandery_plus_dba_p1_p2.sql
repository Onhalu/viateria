-- Trigger-function execute and the membership select initplan.
-- can_record_place_visit stays executable by authenticated: the INSERT
-- policy calls it. The predicate body moves to private in the next migration.

revoke all on function public.touch_vandery_plus_membership()
  from public, anon, authenticated;

revoke all on function public.anonymize_vandery_plus_before_profile_delete()
  from public, anon, authenticated;

drop policy if exists vandery_plus_memberships_select_own
  on public.vandery_plus_memberships;
create policy vandery_plus_memberships_select_own
  on public.vandery_plus_memberships
  for select
  to authenticated
  using ((select auth.uid()) = user_id);
