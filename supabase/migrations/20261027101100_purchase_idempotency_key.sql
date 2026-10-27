-- Checkout attempt id for start-fapi-checkout.
-- The client mints a uuid v4 once per cart (variant + price), including 0 Kč.
-- A retry of that cart sends the same key. A new variant or price uses a new key.

alter table public.purchases
  add column if not exists idempotency_key text;

comment on column public.purchases.idempotency_key is
  'Client checkout attempt id (uuid v4). Retries of the same variant and price reuse it so start-fapi-checkout can dedupe.';

create unique index if not exists purchases_idempotency_key_uidx
  on public.purchases (idempotency_key)
  where idempotency_key is not null;
