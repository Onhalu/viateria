-- Rollback of 20261106120200 only.
-- Restores the membership select policy from 113000 and the execute grant
-- the trigger functions had before this file.
--
-- Rollback apply order, newest first:
--   20261106120900 (cancel flag only),
--   20261106120800 (refund_cents beyond int4),
--   20261106120700 (refund key only when applied),
--   20261106120600 (non-numeric refund_cents),
--   20261106120500 (gross-only full refund),
--   20261106120400 (refund parent gate),
--   20261106120300 (drops private.commit, including 120400 through 120900),
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

-- The transaction starts first. A guard error aborts it, and the final
-- commit rolls that aborted transaction back even when psql continues.

begin;

do $guard$
begin
  if coalesce(current_setting('viateria.allow_destructive_rollback', true), '')
     is distinct from 'on' then
    raise exception 'viateria.allow_destructive_rollback must be on before applying this rollback'
      using errcode = '42501';
  end if;
end
$guard$;

-- Out of order until 120300 has dropped private.commit. The raise aborts
-- this transaction, and the final commit then rolls it back.
do $order$
begin
  if to_regprocedure(
       'private.commit_vandery_plus_event(uuid,uuid,text,text,text,jsonb)'
     ) is not null then
    raise exception 'roll back 20261106120300 before this file; private.commit_vandery_plus_event still exists'
      using errcode = '55000';
  end if;
end
$order$;

drop policy if exists vandery_plus_memberships_select_own
  on public.vandery_plus_memberships;
create policy vandery_plus_memberships_select_own
  on public.vandery_plus_memberships
  for select
  to authenticated
  using (user_id = auth.uid());

grant execute on function public.touch_vandery_plus_membership() to public;
grant execute on function public.anonymize_vandery_plus_before_profile_delete() to public;

-- Plain psql -f commits. The pgTAP include sets vandery_rollback_test so
-- this transaction stays open and the test can roll it back.
\if :{?vandery_rollback_test}
\else
commit;
\endif
