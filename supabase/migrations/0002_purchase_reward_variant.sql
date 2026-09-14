-- Persist the reward product chosen at checkout on the purchase row.
alter table public.purchases
  add column if not exists reward_variant text
  check (
    reward_variant is null
    or reward_variant in ('diploma', 'medal_and_diploma')
  );
