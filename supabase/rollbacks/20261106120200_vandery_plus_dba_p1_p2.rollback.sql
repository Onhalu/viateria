-- Rollback of 20261106120200 only.
-- Restores the membership select policy from 113000 and the execute grant
-- the trigger functions had before this file.
--
-- Rollback apply order, newest first:
--   20261106120800 (refund_cents beyond int4),
--   20261106120700 (refund key only when applied),
--   20261106120600 (non-numeric refund_cents),
--   20261106120500 (gross-only full refund),
--   20261106120400 (refund parent gate),
--   20261106120300 (drops private.commit, including 120400 through 120800),
--   20261106120200,
--   20261106120100,
--   20261106120000,
--   20261106114000,
--   20261106113000.
-- 20261106113000 may instead be applied alone to the full forward chain.
-- That path requires viateria.allow_destructive_rollback=on before it drops
-- vandery_plus_memberships and vandery_plus_webhook_events.
-- Apply this file after 20261106120300 is rolled back, so the public trigger
-- functions exist again.

drop policy if exists vandery_plus_memberships_select_own
  on public.vandery_plus_memberships;
create policy vandery_plus_memberships_select_own
  on public.vandery_plus_memberships
  for select
  to authenticated
  using (user_id = auth.uid());

grant execute on function public.touch_vandery_plus_membership() to public;
grant execute on function public.anonymize_vandery_plus_before_profile_delete() to public;
