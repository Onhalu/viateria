-- Rollback of 20261106114000 only.
-- Drops the catalog added by 114000.
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
-- Apply this file after 20261106120300 has been rolled back (that file
-- tightens diploma grants).
--
-- One transaction, so a guard error aborts the drops even when psql
-- continues after the error.

begin;

do $guard$
begin
  if coalesce(current_setting('viateria.allow_destructive_rollback', true), '')
     is distinct from 'on' then
    raise exception 'viateria.allow_destructive_rollback must be on before dropping vandery_plus_user_diplomas'
      using errcode = '42501';
  end if;
end
$guard$;

drop policy if exists vandery_plus_user_diplomas_select_own
  on public.vandery_plus_user_diplomas;
drop policy if exists vandery_plus_diplomas_select_authenticated
  on public.vandery_plus_diplomas;

drop table if exists public.vandery_plus_user_diplomas;
drop table if exists public.vandery_plus_diplomas;

\if :{?vandery_rollback_test}
\else
commit;
\endif
