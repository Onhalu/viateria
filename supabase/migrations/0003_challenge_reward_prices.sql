-- Per-SKU prices for Digitální diplom vs Medaile + diplom.
--
-- `price_cents` stays as the catalog-card fallback and is the diploma
-- (entry) SKU. Prefer `diploma_price_cents` / `medal_price_cents` on
-- checkout and pay CTAs. When a per-SKU column is null, clients fall
-- back to `price_cents`.
--
-- Optional Stripe Price IDs: `stripe_price_id` remains the legacy
-- shared id. Checkout uses `stripe_price_id_diploma` /
-- `stripe_price_id_medal` for the chosen RewardVariant, then the
-- legacy column.

alter table public.challenges
  add column if not exists diploma_price_cents integer
    check (diploma_price_cents is null or diploma_price_cents >= 0);

alter table public.challenges
  add column if not exists medal_price_cents integer
    check (medal_price_cents is null or medal_price_cents >= 0);

alter table public.challenges
  add column if not exists stripe_price_id_diploma text;

alter table public.challenges
  add column if not exists stripe_price_id_medal text;

-- Existing single price is the diploma / catalog fallback.
update public.challenges
set diploma_price_cents = price_cents
where diploma_price_cents is null;

-- Medal defaults to the same amount until catalog authors set a
-- distinct Medaile + diplom price. Do not copy stripe_price_id onto
-- the medal column — checkout falls back to the legacy id instead.
update public.challenges
set medal_price_cents = price_cents
where medal_price_cents is null;

update public.challenges
set stripe_price_id_diploma = stripe_price_id
where stripe_price_id_diploma is null
  and stripe_price_id is not null;
