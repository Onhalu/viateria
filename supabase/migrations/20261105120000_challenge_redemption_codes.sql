-- Challenge redemption codes (SPEC-challenge-redemption-codes, SCHVÁLENO 2026-11-05).
-- OQ-R1–R10 LOCK. Hash only. No UNIQUE on (challenge_id, buyer_email) (OQ-R3).
-- Do NOT apply to production from the implementation PR. Prod apply is Ask first
-- (DBA / Supabase GitHub app). This file is the review artifact only.
--
-- Redeem is public.redeem_challenge_code, EXECUTE for service_role only.
-- The Edge function redeem-challenge-code is the client entry point.

create table if not exists public.challenge_redemption_codes (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id),
  code_hash text not null,
  code_hint text,
  buyer_email text not null,
  expires_at timestamptz,
  redeemed_at timestamptz,
  redeemed_by uuid references public.profiles (id),
  purchase_id uuid references public.purchases (id) on delete set null,
  source text not null default 'vyslapni_cz',
  created_at timestamptz not null default now(),
  created_by text,
  constraint challenge_redemption_codes_hash_hex
    check (code_hash ~ '^[0-9a-f]{64}$'),
  constraint challenge_redemption_codes_buyer_email_folded
    check (
      buyer_email = lower(btrim(buyer_email))
      and length(buyer_email) > 0
    ),
  constraint challenge_redemption_codes_source_present
    check (length(btrim(source)) > 0),
  constraint challenge_redemption_codes_redeemed_check
    check (redeemed_at is null or redeemed_by is not null),
  constraint challenge_redemption_codes_challenge_hash_key
    unique (challenge_id, code_hash)
);

comment on table public.challenge_redemption_codes is
  'Single-use vyšlápni.cz codes. Plaintext never stored. No unique on (challenge_id, buyer_email): one buyer may hold several codes (OQ-R3).';

comment on column public.challenge_redemption_codes.code_hash is
  'Lowercase hex SHA-256 of normalize(code): upper(trim), strip spaces and dashes. 8–16 of A–Z0–9.';

comment on column public.challenge_redemption_codes.code_hint is
  'Optional last 4 characters of the normalized code, for support. Not a secret substitute for the hash.';

comment on column public.challenge_redemption_codes.buyer_email is
  'Folded lower(trim). Must match the JWT email at redeem.';

comment on column public.challenge_redemption_codes.expires_at is
  'Null means no expiry (OQ-R8). CSV import may set a timestamp.';

-- Lookup unused codes by buyer. Not a uniqueness constraint.
create index if not exists challenge_redemption_codes_buyer_unused_idx
  on public.challenge_redemption_codes (buyer_email)
  where redeemed_at is null;

-- Rolling window for Edge rate limit: 10 attempts / 15 min / user (OQ-R7).
create table if not exists public.challenge_redemption_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  attempted_at timestamptz not null default now()
);

comment on table public.challenge_redemption_attempts is
  'Redeem attempts for the 10 / 15 min / user rate limit. No code material is stored.';

create index if not exists challenge_redemption_attempts_user_idx
  on public.challenge_redemption_attempts (user_id, attempted_at desc);

alter table public.challenge_redemption_codes enable row level security;
alter table public.challenge_redemption_attempts enable row level security;

revoke all on table public.challenge_redemption_codes from public, anon, authenticated;
revoke all on table public.challenge_redemption_attempts from public, anon, authenticated;
grant all on table public.challenge_redemption_codes to service_role;
grant all on table public.challenge_redemption_attempts to service_role;

drop policy if exists challenge_redemption_codes_deny_client
  on public.challenge_redemption_codes;
create policy challenge_redemption_codes_deny_client
  on public.challenge_redemption_codes
  for all
  to anon, authenticated
  using (false)
  with check (false);

drop policy if exists challenge_redemption_attempts_deny_client
  on public.challenge_redemption_attempts;
create policy challenge_redemption_attempts_deny_client
  on public.challenge_redemption_attempts
  for all
  to anon, authenticated
  using (false)
  with check (false);

-- Atomic redeem. Edge passes the hash, never the plaintext.
-- already_unlocked does not mark the code redeemed (OQ-R5).
create or replace function public.redeem_challenge_code(
  p_user_id uuid,
  p_email text,
  p_challenge_id uuid,
  p_code_hash text,
  p_format_ok boolean
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempts integer;
  v_email text;
  v_id uuid;
  v_buyer_email text;
  v_expires_at timestamptz;
  v_redeemed_at timestamptz;
  v_other boolean;
  v_status text;
  v_access text;
  v_pricing text;
  v_currency text;
  v_purchase_id uuid;
  v_purchase_status text;
  v_result jsonb;
begin
  if p_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  -- One redeem at a time per user so the paid-row check and the rate window
  -- do not race with a second request from the same account.
  perform pg_advisory_xact_lock(hashtext('redeem:' || p_user_id::text)::bigint);

  delete from public.challenge_redemption_attempts
  where user_id = p_user_id
    and attempted_at < now() - interval '15 minutes';

  insert into public.challenge_redemption_attempts (user_id)
  values (p_user_id);

  select count(*)::integer into v_attempts
  from public.challenge_redemption_attempts
  where user_id = p_user_id
    and attempted_at > now() - interval '15 minutes';

  if v_attempts > 10 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;

  if p_format_ok is not true then
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  v_email := lower(btrim(coalesce(p_email, '')));
  if v_email = '' then
    return jsonb_build_object('ok', false, 'error', 'email_mismatch');
  end if;

  select c.id, c.buyer_email, c.expires_at, c.redeemed_at
    into v_id, v_buyer_email, v_expires_at, v_redeemed_at
  from public.challenge_redemption_codes c
  where c.code_hash = p_code_hash
    and c.challenge_id = p_challenge_id
  for update;

  if not found then
    select exists (
      select 1
      from public.challenge_redemption_codes c
      where c.code_hash = p_code_hash
        and c.challenge_id is distinct from p_challenge_id
    ) into v_other;
    if v_other then
      return jsonb_build_object('ok', false, 'error', 'challenge_mismatch');
    end if;
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  if v_redeemed_at is not null then
    return jsonb_build_object('ok', false, 'error', 'already_redeemed');
  end if;

  if v_expires_at is not null and v_expires_at <= now() then
    return jsonb_build_object('ok', false, 'error', 'expired');
  end if;

  if lower(btrim(v_buyer_email)) is distinct from v_email then
    return jsonb_build_object('ok', false, 'error', 'email_mismatch');
  end if;

  select ch.status, ch.access_mode, ch.pricing_type, ch.currency
    into v_status, v_access, v_pricing, v_currency
  from public.challenges ch
  where ch.id = p_challenge_id;

  -- Story, free, draft, and missing challenges do not unlock and do not
  -- consume the code. The response stays invalid_code (no extra oracle).
  if v_status is distinct from 'published'
     or v_access is distinct from 'open'
     or v_pricing is distinct from 'paid' then
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  v_currency := coalesce(nullif(btrim(v_currency), ''), 'eur');

  select p.id, p.status
    into v_purchase_id, v_purchase_status
  from public.purchases p
  where p.user_id = p_user_id
    and p.challenge_id = p_challenge_id
  for update;

  -- OQ-R5: an existing paid row leaves the code unused.
  if v_purchase_status = 'paid' then
    return jsonb_build_object(
      'ok', true,
      'challenge_id', p_challenge_id,
      'already_unlocked', true
    );
  end if;

  begin
    update public.challenge_redemption_codes
    set redeemed_at = now(),
        redeemed_by = p_user_id
    where id = v_id
      and redeemed_at is null;

    if not found then
      return jsonb_build_object('ok', false, 'error', 'already_redeemed');
    end if;

    if v_purchase_id is null then
      insert into public.purchases (
        user_id,
        challenge_id,
        status,
        amount_cents,
        currency,
        reward_variant,
        paid_at
      ) values (
        p_user_id,
        p_challenge_id,
        'paid',
        0,
        v_currency,
        'medal_and_diploma',
        now()
      )
      returning id into v_purchase_id;
    else
      update public.purchases
      set status = 'paid',
          amount_cents = 0,
          currency = v_currency,
          reward_variant = 'medal_and_diploma',
          paid_at = coalesce(paid_at, now())
      where id = v_purchase_id;
    end if;

    update public.challenge_redemption_codes
    set purchase_id = v_purchase_id
    where id = v_id;

    v_result := jsonb_build_object(
      'ok', true,
      'challenge_id', p_challenge_id,
      'already_unlocked', false,
      'purchase_id', v_purchase_id
    );
  exception
    when unique_violation then
      -- The other request already wrote purchases (user_id, challenge_id).
      -- Roll back this code mark so the code stays unused (OQ-R5).
      v_result := jsonb_build_object(
        'ok', true,
        'challenge_id', p_challenge_id,
        'already_unlocked', true
      );
  end;

  return v_result;
end;
$$;

comment on function public.redeem_challenge_code(uuid, text, uuid, text, boolean) is
  'Service-role redeem. Marks the code, then upserts purchases paid medal_and_diploma amount 0. Does not consume the code when the user is already paid.';

revoke all on function public.redeem_challenge_code(uuid, text, uuid, text, boolean)
  from public, anon, authenticated;
grant execute on function public.redeem_challenge_code(uuid, text, uuid, text, boolean)
  to service_role;
