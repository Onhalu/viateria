-- VANDERY+ membership entitlement (SPEC §5–§6, A2, A3, A5).
--
-- Local / CI only. Do not apply to prod. Staging apply is Ask first.
-- Does not change leaderboard_rows, get_leaderboard, get_my_score, or
-- verify_waypoint. Map visits (source = map) require an active membership.
-- Challenge verify_waypoint keeps writing source = verify without one.

create table if not exists public.vandery_plus_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id) on delete set null,
  status text not null,
  starts_at timestamptz,
  expires_at timestamptz not null,
  cancel_at_period_end boolean not null default false,
  fapi_subscription_id text,
  fapi_invoice_id text,
  amount_cents integer,
  currency text,
  anonymized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vandery_plus_memberships_status_check check (
    status in ('pending', 'active', 'expired', 'revoked', 'failed')
  ),
  constraint vandery_plus_memberships_amount_check check (
    amount_cents is null or amount_cents >= 0
  ),
  constraint vandery_plus_memberships_currency_check check (
    currency is null or currency ~ '^[A-Za-z]{3}$'
  ),
  constraint vandery_plus_memberships_user_or_tombstone check (
    user_id is not null or anonymized_at is not null
  )
);

comment on table public.vandery_plus_memberships is
  'One current VANDERY+ row per user. Webhook extends it in place. Not purchases.';

comment on column public.vandery_plus_memberships.user_id is
  'Null after account delete (tombstone). Accounting columns stay.';

comment on column public.vandery_plus_memberships.anonymized_at is
  'Set when the profile is deleted. The row is kept for the accounting trace.';

-- One live row per user. Anonymized tombstones are excluded so they do not collide.
create unique index if not exists vandery_plus_memberships_one_current_uidx
  on public.vandery_plus_memberships (user_id)
  where user_id is not null
    and anonymized_at is null
    and status in ('pending', 'active', 'expired', 'revoked', 'failed');

create index if not exists vandery_plus_memberships_active_lookup_idx
  on public.vandery_plus_memberships (user_id, expires_at)
  where status = 'active' and anonymized_at is null;

create index if not exists vandery_plus_memberships_subscription_idx
  on public.vandery_plus_memberships (fapi_subscription_id)
  where fapi_subscription_id is not null;

create table if not exists public.vandery_plus_webhook_events (
  idempotency_key text primary key,
  event_kind text not null,
  user_id uuid,
  fapi_invoice_id text,
  created_at timestamptz not null default now(),
  constraint vandery_plus_webhook_events_kind_check check (
    event_kind in ('paid_first', 'renew', 'cancel', 'refund', 'payment_failed')
  )
);

comment on table public.vandery_plus_webhook_events is
  'Webhook idempotency. A repeated kind+invoice does not extend the period again.';

alter table public.vandery_plus_memberships enable row level security;
alter table public.vandery_plus_webhook_events enable row level security;

drop policy if exists vandery_plus_memberships_select_own
  on public.vandery_plus_memberships;
create policy vandery_plus_memberships_select_own
  on public.vandery_plus_memberships
  for select
  to authenticated
  using (user_id = auth.uid());

-- No INSERT / UPDATE / DELETE policy: authenticated clients cannot write.
-- No policy on webhook events: clients cannot read or write them.
-- service_role bypasses RLS and is the only writer.

revoke all on table public.vandery_plus_memberships from public, anon, authenticated;
grant select on table public.vandery_plus_memberships to authenticated;

revoke all on table public.vandery_plus_webhook_events from public, anon, authenticated;

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

drop trigger if exists vandery_plus_memberships_touch
  on public.vandery_plus_memberships;
create trigger vandery_plus_memberships_touch
  before update on public.vandery_plus_memberships
  for each row execute function public.touch_vandery_plus_membership();

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
  -- Do not leak another user's boolean to a normal session.
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

comment on function public.has_active_vandery_plus(uuid) is
  'True when status is active and expires_at is still in the future. Soft-cancel does not end access early.';

revoke all on function public.has_active_vandery_plus(uuid) from public, anon;
grant execute on function public.has_active_vandery_plus(uuid)
  to authenticated, service_role;

-- Shared predicate for the RPC and the INSERT policy (no RLS recursion).
create or replace function public.can_record_place_visit(p_source text)
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
    -- Challenge verify_waypoint inserts directly. SPEC §6 does not block
    -- source = verify. See T0 residual risk for the client RPC.
    return true;
  end if;
  if p_source = 'map' then
    return public.has_active_vandery_plus(uid);
  end if;
  if p_source = 'prefs_sync' then
    -- DBA default (SPEC §6 Ask): historical sync only, or a member.
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

drop policy if exists place_visits_insert_own on public.place_visits;
create policy place_visits_insert_own
  on public.place_visits
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.can_record_place_visit(source)
  );

create or replace function public.record_place_visit(
  p_place_id uuid,
  p_source text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if p_source is null or p_source not in ('map', 'verify', 'prefs_sync') then
    raise exception 'invalid source';
  end if;
  if not public.can_record_place_visit(p_source) then
    raise exception 'membership_required' using errcode = 'P0001';
  end if;

  insert into public.place_visits (user_id, place_id, source)
  select uid, p.id, p_source
  from public.places p
  where p.id = p_place_id
  on conflict (user_id, place_id) do nothing;
end;
$$;

create or replace function public.record_place_visits_batch(
  p_place_ids uuid[],
  p_source text default 'prefs_sync'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if p_source is null or p_source not in ('map', 'verify', 'prefs_sync') then
    raise exception 'invalid source';
  end if;
  if not public.can_record_place_visit(p_source) then
    raise exception 'membership_required' using errcode = 'P0001';
  end if;

  insert into public.place_visits (user_id, place_id, source)
  select distinct uid, p.id, p_source
  from public.places p
  join unnest(coalesce(p_place_ids, array[]::uuid[])) as incoming (id)
    on incoming.id = p.id
  on conflict (user_id, place_id) do nothing;
end;
$$;

revoke all on function public.record_place_visit(uuid, text) from public, anon;
revoke all on function public.record_place_visits_batch(uuid[], text) from public, anon;
grant execute on function public.record_place_visit(uuid, text) to authenticated;
grant execute on function public.record_place_visits_batch(uuid[], text) to authenticated;

comment on function public.record_place_visit(uuid, text) is
  'Records one place visit. source=map requires an active VANDERY+ membership. verify_waypoint is a separate function and is not gated.';

-- Service-role commit. Transition rules live in the Edge reducer.
-- This function enforces the checkout user, the idempotency key, and the
-- allow-listed columns. It never writes purchases.
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
  row public.vandery_plus_memberships%rowtype;
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

  select * into row
  from public.vandery_plus_memberships
  where id = p_membership_id
  for update;

  if not found then
    return jsonb_build_object('status', 'rejected', 'reason', 'no_checkout');
  end if;

  -- Checkout session user only. A client-supplied user never retargets the row.
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
  values (p_idempotency_key, p_kind, p_user_id, p_invoice_id)
  on conflict (idempotency_key) do nothing;
  get diagnostics inserted = row_count;

  if inserted = 0 then
    return jsonb_build_object(
      'status', 'ok',
      'idempotent', true,
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
    'status', 'ok',
    'idempotent', false,
    'membership_status', row.status,
    'expires_at', row.expires_at,
    'cancel_at_period_end', row.cancel_at_period_end
  );
end;
$$;

comment on function public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb) is
  'Webhook commit for the checkout user only. Idempotent on kind:invoice. Never writes purchases.';

revoke all on function public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.commit_vandery_plus_event(uuid, uuid, text, text, text, jsonb)
  to service_role;

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

comment on function public.anonymize_vandery_plus_membership(uuid) is
  'Account delete: keep the accounting row, drop the user link and subscription id.';

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

drop trigger if exists vandery_plus_anonymize_on_profile_delete on public.profiles;
create trigger vandery_plus_anonymize_on_profile_delete
  before delete on public.profiles
  for each row execute function public.anonymize_vandery_plus_before_profile_delete();
