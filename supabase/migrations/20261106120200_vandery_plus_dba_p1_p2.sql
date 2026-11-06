-- DBA follow-ups. Not the revertible map-gate guard.
--
-- P1 least privilege: clients do not execute the visit predicate or the
-- trigger functions. The security-definer RPCs still call the predicate
-- as the function owner.
-- P2 RLS initplan: auth.uid() is evaluated once per statement.

revoke all on function public.can_record_place_visit(text)
  from public, anon, authenticated;

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
