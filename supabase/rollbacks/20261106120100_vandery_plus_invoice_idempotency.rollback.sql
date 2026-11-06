-- Rollback of 20261106120100 only.
-- Restores the 113000 body, which stores the caller-supplied idempotency key,
-- and restores that migration's function comment.
--
-- Rollback apply order, newest first:
--   20261106120300 (drops private.commit, including the 120400 refund gate),
--   20261106120200,
--   20261106120100,
--   20261106120000,
--   20261106114000,
--   20261106113000.
-- 20261106113000 may instead be applied alone to the full forward chain.
-- That path requires viateria.allow_destructive_rollback=on before it drops
-- vandery_plus_memberships and vandery_plus_webhook_events.
-- Apply this file after 20261106120300 is rolled back, so
-- public.commit_vandery_plus_event is the plpgsql function from 120100 again.

create or replace function public.commit_vandery_plus_event(
  p_membership_id uuid,
  p_user_id uuid,
  p_idempotency_key text,
  p_kind text,
  p_invoice_id text,
  p_patch jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  membership public.vandery_plus_memberships%rowtype;
  inserted int;
  new_status text;
begin
  if p_kind is null
     or p_kind not in ('paid_first', 'renew', 'cancel', 'refund', 'payment_failed') then
    raise exception 'invalid event';
  end if;
  if p_idempotency_key is null or length(trim(p_idempotency_key)) = 0 then
    raise exception 'idempotency key required';
  end if;
  if p_invoice_id is null or length(trim(p_invoice_id)) = 0 then
    raise exception 'invoice required';
  end if;

  select * into membership
  from public.vandery_plus_memberships
  where id = p_membership_id
  for update;

  if not found then
    return jsonb_build_object('status', 'rejected', 'reason', 'no_checkout');
  end if;

  if membership.user_id is distinct from p_user_id
     or membership.anonymized_at is not null then
    return jsonb_build_object('status', 'rejected', 'reason', 'user_mismatch');
  end if;

  if p_patch ? 'status' then
    new_status := p_patch->>'status';
    if new_status is null
       or new_status not in ('pending', 'active', 'expired', 'revoked', 'failed') then
      raise exception 'invalid status';
    end if;
  end if;

  insert into public.vandery_plus_webhook_events (
    idempotency_key, event_kind, user_id, fapi_invoice_id
  )
  values (p_idempotency_key, p_kind, p_user_id, p_invoice_id)
  on conflict (idempotency_key) do nothing;
  get diagnostics inserted = row_count;

  if inserted = 0 then
    return jsonb_build_object(
      'status', 'ok',
      'idempotent', true,
      'membership_status', membership.status,
      'expires_at', membership.expires_at,
      'cancel_at_period_end', membership.cancel_at_period_end
    );
  end if;

  if p_patch is not null and p_patch <> '{}'::jsonb then
    update public.vandery_plus_memberships
    set
      status = coalesce(p_patch->>'status', status),
      starts_at = case
        when p_patch ? 'starts_at' then (p_patch->>'starts_at')::timestamptz
        else starts_at
      end,
      expires_at = case
        when p_patch ? 'expires_at' then (p_patch->>'expires_at')::timestamptz
        else expires_at
      end,
      cancel_at_period_end = case
        when p_patch ? 'cancel_at_period_end'
          then (p_patch->>'cancel_at_period_end')::boolean
        else cancel_at_period_end
      end,
      fapi_subscription_id = case
        when p_patch ? 'fapi_subscription_id' then p_patch->>'fapi_subscription_id'
        else fapi_subscription_id
      end,
      fapi_invoice_id = case
        when p_patch ? 'fapi_invoice_id' then p_patch->>'fapi_invoice_id'
        else fapi_invoice_id
      end,
      amount_cents = case
        when p_patch ? 'amount_cents' then (p_patch->>'amount_cents')::integer
        else amount_cents
      end,
      currency = case
        when p_patch ? 'currency' then p_patch->>'currency'
        else currency
      end
    where id = p_membership_id
    returning * into membership;
  end if;

  return jsonb_build_object(
    'status', 'ok',
    'idempotent', false,
    'membership_status', membership.status,
    'expires_at', membership.expires_at,
    'cancel_at_period_end', membership.cancel_at_period_end
  );
end;
$$;

comment on function public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb) is
  'Webhook commit for the checkout user only. Idempotent on kind:invoice. Never writes purchases.';

revoke all on function public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb)
  to service_role;
