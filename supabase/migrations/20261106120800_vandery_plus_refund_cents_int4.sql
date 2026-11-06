-- refund_cents outside int4 is 22023, same as a non-numeric value.
-- The numeric cast is only reached after the text matches an integer.

create or replace function private.commit_vandery_plus_event(
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
  v_key text;
  v_invoice text;
  v_refund_parent text;
  v_refund_cents integer;
  v_refund_alert text;
  v_original integer;
begin
  if p_kind is null
     or p_kind not in ('paid_first', 'renew', 'cancel', 'refund', 'payment_failed') then
    raise exception 'invalid event';
  end if;
  if p_idempotency_key is not null and char_length(p_idempotency_key) > 200 then
    raise exception 'idempotency key too long' using errcode = '22023';
  end if;
  if p_invoice_id is null or length(trim(p_invoice_id)) = 0 then
    raise exception 'invoice required';
  end if;
  v_invoice := trim(p_invoice_id);
  v_key := case
    when p_kind in ('paid_first', 'renew') then 'paid:' || v_invoice
    else p_kind || ':' || v_invoice
  end;

  -- Lock the membership for this commit, including renew, so two invoices
  -- cannot lose an update.
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

  -- Same invoice already activated or renewed: do not add another month,
  -- even when the caller passes a different kind prefix as the key.
  if p_kind in ('paid_first', 'renew') and exists (
    select 1
    from public.vandery_plus_webhook_events e
    where e.fapi_invoice_id = v_invoice
      and e.event_kind in ('paid_first', 'renew')
  ) then
    return jsonb_build_object(
      'status', 'ok',
      'idempotent', true,
      'membership_status', membership.status,
      'expires_at', membership.expires_at,
      'cancel_at_period_end', membership.cancel_at_period_end
    );
  end if;

  -- Refunds are tied to the original paid invoice. A missing parent, a
  -- parent with no paid_first/renew for this user, or an older invoice
  -- is vandery_plus_refund_unmatched. A current-period parent whose
  -- amount is not a full refund is vandery_plus_refund_partial.
  -- Neither changes the membership row, and neither writes the idempotency key.
  if p_kind = 'refund' then
    v_refund_parent := nullif(btrim(coalesce(p_patch->>'refund_parent', '')), '');
    if v_refund_parent = '0' then
      v_refund_parent := null;
    end if;
    v_refund_cents := null;
    if p_patch ? 'refund_cents'
       and nullif(btrim(p_patch->>'refund_cents'), '') is not null then
      if btrim(p_patch->>'refund_cents') !~ '^-?[0-9]+$' then
        raise exception 'refund_cents must be an integer' using errcode = '22023';
      elsif abs(btrim(p_patch->>'refund_cents')::numeric) > 2147483647 then
        raise exception 'refund_cents must be an integer' using errcode = '22023';
      end if;
      v_refund_cents := abs(btrim(p_patch->>'refund_cents')::numeric)::integer;
    end if;
    v_original := membership.amount_cents;

    if v_refund_parent is null
       or v_refund_parent is distinct from membership.fapi_invoice_id
       or not exists (
         select 1
         from public.vandery_plus_webhook_events e
         where e.user_id = membership.user_id
           and e.fapi_invoice_id = v_refund_parent
           and e.event_kind in ('paid_first', 'renew')
       )
    then
      v_refund_alert := 'vandery_plus_refund_unmatched';
    elsif v_original is null
       or v_refund_cents is null
       or abs(v_refund_cents - v_original) > 100
    then
      v_refund_alert := 'vandery_plus_refund_partial';
    else
      v_refund_alert := null;
    end if;

    if v_refund_alert is not null then
      return jsonb_build_object(
        'status', 'ok',
        'idempotent', false,
        'alert', v_refund_alert,
        'membership_status', membership.status,
        'expires_at', membership.expires_at,
        'cancel_at_period_end', membership.cancel_at_period_end
      );
    end if;
  end if;

  begin
    insert into public.vandery_plus_webhook_events (
      idempotency_key, event_kind, user_id, fapi_invoice_id
    )
    values (v_key, p_kind, p_user_id, v_invoice)
    on conflict (idempotency_key) do nothing;
    get diagnostics inserted = row_count;
  exception
    when unique_violation then
      inserted := 0;
  end;

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
        when p_kind = 'renew'
          then greatest(expires_at, now()) + interval '1 month'
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

comment on function private.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb) is
  'Webhook commit. A refund revokes only for the current paid invoice within 1 CZK of the gross amount.';
