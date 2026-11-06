-- DBA P1 index and P2 helpers.
-- Does not change ON DELETE behaviour of purchases or challenge_diplomas.
--
-- P1: one paid_first/renew row per invoice id, even when the idempotency
-- key string differs (paid_first:<id> vs renew:<id>).
-- P2: security-definer bodies live in private. Public wrappers stay only
-- where the INSERT policy or the service-role RPC needs a public name.
-- The membership row is locked with SELECT … FOR UPDATE inside the commit.

create unique index if not exists vandery_plus_webhook_paid_invoice_uidx
  on public.vandery_plus_webhook_events (fapi_invoice_id)
  where event_kind in ('paid_first', 'renew')
    and fapi_invoice_id is not null;

drop index if exists public.vandery_plus_memberships_one_current_uidx;
create unique index vandery_plus_memberships_one_current_uidx
  on public.vandery_plus_memberships (user_id)
  where user_id is not null
    and anonymized_at is null;

create or replace function private.has_active_vandery_plus(
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

revoke all on function private.has_active_vandery_plus(uuid) from public, anon;
grant execute on function private.has_active_vandery_plus(uuid)
  to authenticated, service_role;

drop function if exists public.has_active_vandery_plus(uuid);
create function public.has_active_vandery_plus(p_uid uuid default auth.uid())
returns boolean
language sql
stable
security invoker
set search_path = public, private
as $$
  select private.has_active_vandery_plus(p_uid);
$$;

revoke all on function public.has_active_vandery_plus(uuid) from public, anon;
grant execute on function public.has_active_vandery_plus(uuid)
  to authenticated, service_role;

create or replace function private.can_record_place_visit(p_source text)
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
    return private.has_active_vandery_plus(uid);
  end if;
  if p_source = 'prefs_sync' then
    return private.has_active_vandery_plus(uid)
      or exists (
        select 1
        from public.place_visits v
        where v.user_id = uid
      );
  end if;
  return false;
end;
$$;

revoke all on function private.can_record_place_visit(text) from public, anon;
grant execute on function private.can_record_place_visit(text)
  to authenticated, service_role;

-- Drop the policy before the function it depends on.
-- DROP FUNCTION while the policy exists fails with 2BP01. No CASCADE.
drop policy if exists place_visits_insert_own on public.place_visits;

drop function if exists public.can_record_place_visit(text);
create function public.can_record_place_visit(p_source text)
returns boolean
language sql
stable
security invoker
set search_path = public, private
as $$
  select private.can_record_place_visit(p_source);
$$;

revoke all on function public.can_record_place_visit(text) from public, anon;
grant execute on function public.can_record_place_visit(text)
  to authenticated, service_role;

create policy place_visits_insert_own
  on public.place_visits
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and public.can_record_place_visit(source)
  );

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

revoke all on function private.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function private.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb)
  to service_role;

drop function if exists public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb);
create function public.commit_vandery_plus_event(
  p_membership_id uuid,
  p_user_id uuid,
  p_idempotency_key text,
  p_kind text,
  p_invoice_id text,
  p_patch jsonb
)
returns jsonb
language sql
security definer
set search_path = public, private
as $$
  select private.commit_vandery_plus_event(
    p_membership_id,
    p_user_id,
    p_idempotency_key,
    p_kind,
    p_invoice_id,
    p_patch
  );
$$;

revoke all on function public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb)
  to service_role;

comment on function private.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb) is
  'Webhook commit. Locks the membership row. Idempotent on invoice id for paid_first and renew.';

create or replace function private.touch_vandery_plus_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function private.anonymize_vandery_plus_membership(p_user_id uuid)
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

create or replace function private.anonymize_vandery_plus_before_profile_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform private.anonymize_vandery_plus_membership(old.id);
  return old;
end;
$$;

revoke all on function private.touch_vandery_plus_membership()
  from public, anon, authenticated;
revoke all on function private.anonymize_vandery_plus_membership(uuid)
  from public, anon, authenticated;
revoke all on function private.anonymize_vandery_plus_before_profile_delete()
  from public, anon, authenticated;
grant execute on function private.anonymize_vandery_plus_membership(uuid)
  to service_role;

drop trigger if exists vandery_plus_memberships_touch
  on public.vandery_plus_memberships;
create trigger vandery_plus_memberships_touch
  before update on public.vandery_plus_memberships
  for each row execute function private.touch_vandery_plus_membership();

drop trigger if exists vandery_plus_anonymize_on_profile_delete on public.profiles;
create trigger vandery_plus_anonymize_on_profile_delete
  before delete on public.profiles
  for each row execute function private.anonymize_vandery_plus_before_profile_delete();

drop function if exists public.touch_vandery_plus_membership();
drop function if exists public.anonymize_vandery_plus_before_profile_delete();
drop function if exists public.anonymize_vandery_plus_membership(uuid);

-- Hidden catalog rows, and unlock_rule on every row, stay off the client.
drop policy if exists vandery_plus_diplomas_select_authenticated
  on public.vandery_plus_diplomas;
create policy vandery_plus_diplomas_select_authenticated
  on public.vandery_plus_diplomas
  for select
  to authenticated
  using (
    is_hidden = false
    or exists (
      select 1
      from public.vandery_plus_user_diplomas u
      where u.diploma_id = vandery_plus_diplomas.id
        and u.user_id = (select auth.uid())
    )
  );

revoke all on table public.vandery_plus_diplomas from authenticated;
grant select (
  id,
  slug,
  title_i18n,
  is_hidden,
  asset_ref,
  created_at
) on public.vandery_plus_diplomas to authenticated;

drop policy if exists vandery_plus_user_diplomas_select_own
  on public.vandery_plus_user_diplomas;
create policy vandery_plus_user_diplomas_select_own
  on public.vandery_plus_user_diplomas
  for select
  to authenticated
  using (user_id = (select auth.uid()));
