-- Rollback of 20261106120300 only.
-- Drops private.* (including the 120400 refund gate) and restores the public
-- security-definer helpers and the diploma grants from 114000 / the
-- place-visit predicate from 120000.
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
-- The paid-invoice partial unique index from this migration is dropped here.

drop index if exists public.vandery_plus_webhook_paid_invoice_uidx;

drop index if exists public.vandery_plus_memberships_one_current_uidx;
create unique index vandery_plus_memberships_one_current_uidx
  on public.vandery_plus_memberships (user_id)
  where user_id is not null
    and anonymized_at is null
    and status in ('pending', 'active', 'expired', 'revoked', 'failed');

drop trigger if exists vandery_plus_anonymize_on_profile_delete on public.profiles;
drop trigger if exists vandery_plus_memberships_touch on public.vandery_plus_memberships;

-- Policy and public SQL wrappers depend on the functions they call.
-- Drop the policy, then the public wrappers, then private.*.
drop policy if exists place_visits_insert_own on public.place_visits;
drop function if exists public.can_record_place_visit(text);
drop function if exists public.has_active_vandery_plus(uuid);
drop function if exists public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb);

drop function if exists private.anonymize_vandery_plus_before_profile_delete();
drop function if exists private.anonymize_vandery_plus_membership(uuid);
drop function if exists private.touch_vandery_plus_membership();
drop function if exists private.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb);
drop function if exists private.can_record_place_visit(text);
drop function if exists private.has_active_vandery_plus(uuid);

create or replace function public.has_active_vandery_plus(
  p_uid uuid default auth.uid()
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_uid is null then
    return false;
  end if;
  if coalesce(auth.role(), '') is distinct from 'service_role'
     and p_uid is distinct from auth.uid() then
    return false;
  end if;
  return exists (
    select 1
    from public.vandery_plus_memberships m
    where m.user_id = p_uid
      and m.anonymized_at is null
      and m.status = 'active'
      and m.expires_at > now()
  );
end;
$$;

revoke all on function public.has_active_vandery_plus(uuid) from public, anon;
grant execute on function public.has_active_vandery_plus(uuid)
  to authenticated, service_role;

create function public.can_record_place_visit(p_source text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    return false;
  end if;
  if p_source = 'verify' then
    return false;
  end if;
  if p_source = 'map' then
    return public.has_active_vandery_plus(uid);
  end if;
  if p_source = 'prefs_sync' then
    return public.has_active_vandery_plus(uid)
      or exists (
        select 1
        from public.place_visits v
        where v.user_id = uid
      );
  end if;
  return false;
end;
$$;

revoke all on function public.can_record_place_visit(text) from public, anon;
grant execute on function public.can_record_place_visit(text)
  to authenticated, service_role;

create policy place_visits_insert_own
  on public.place_visits
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.can_record_place_visit(source)
  );

-- Commit function returns to the 120100 body. Re-apply that file's function
-- by calling the 120100 rollback's inverse: the forward 120100 definition.
-- Kept inline so this file does not depend on psql \i.

create function public.commit_vandery_plus_event(
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
  row public.vandery_plus_memberships%rowtype;
  inserted int;
  new_status text;
  v_key text;
  v_invoice text;
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

  select * into row
  from public.vandery_plus_memberships
  where id = p_membership_id
  for update;

  if not found then
    return jsonb_build_object('status', 'rejected', 'reason', 'no_checkout');
  end if;
  if row.user_id is distinct from p_user_id or row.anonymized_at is not null then
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
  values (v_key, p_kind, p_user_id, v_invoice)
  on conflict (idempotency_key) do nothing;
  get diagnostics inserted = row_count;

  if inserted = 0 then
    return jsonb_build_object(
      'status', 'ok', 'idempotent', true,
      'membership_status', row.status,
      'expires_at', row.expires_at,
      'cancel_at_period_end', row.cancel_at_period_end
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
    returning * into row;
  end if;

  return jsonb_build_object(
    'status', 'ok', 'idempotent', false,
    'membership_status', row.status,
    'expires_at', row.expires_at,
    'cancel_at_period_end', row.cancel_at_period_end
  );
end;
$$;

revoke all on function public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb)
  to service_role;

create or replace function public.touch_vandery_plus_membership()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.anonymize_vandery_plus_membership(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;
  update public.vandery_plus_memberships
  set
    user_id = null,
    anonymized_at = coalesce(anonymized_at, now()),
    fapi_subscription_id = null
  where user_id = p_user_id;
  update public.vandery_plus_webhook_events
  set user_id = null
  where user_id = p_user_id;
end;
$$;

revoke all on function public.anonymize_vandery_plus_membership(uuid)
  from public, anon, authenticated;
grant execute on function public.anonymize_vandery_plus_membership(uuid)
  to service_role;

create or replace function public.anonymize_vandery_plus_before_profile_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.anonymize_vandery_plus_membership(old.id);
  return old;
end;
$$;

create trigger vandery_plus_memberships_touch
  before update on public.vandery_plus_memberships
  for each row execute function public.touch_vandery_plus_membership();

create trigger vandery_plus_anonymize_on_profile_delete
  before delete on public.profiles
  for each row execute function public.anonymize_vandery_plus_before_profile_delete();

-- 120200 revoked these. Recreating the functions grants execute to public
-- again, so put that revoke back. The 120200 rollback grants it once more.
revoke all on function public.touch_vandery_plus_membership()
  from public, anon, authenticated;
revoke all on function public.anonymize_vandery_plus_before_profile_delete()
  from public, anon, authenticated;

comment on function public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb) is
  'Webhook commit for the checkout user only. Idempotent on invoice id. Never writes purchases.';

drop policy if exists vandery_plus_diplomas_select_authenticated
  on public.vandery_plus_diplomas;
create policy vandery_plus_diplomas_select_authenticated
  on public.vandery_plus_diplomas
  for select
  to authenticated
  using (true);

grant select on table public.vandery_plus_diplomas to authenticated;

drop policy if exists vandery_plus_user_diplomas_select_own
  on public.vandery_plus_user_diplomas;
create policy vandery_plus_user_diplomas_select_own
  on public.vandery_plus_user_diplomas
  for select
  to authenticated
  using (user_id = auth.uid());
