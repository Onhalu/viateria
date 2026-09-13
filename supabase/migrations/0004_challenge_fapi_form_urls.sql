-- FAPI sales-form URLs for the two pay-CTA SKUs.
--
-- Nullable on purpose: catalog authors paste the public form page URL
-- after creating the forms in FAPI. An empty / null URL disables that
-- variant's pay CTA. Do not invent production URLs in seeds.
--
--   fapi_form_url_diploma  → Digitální diplom / RewardVariant.diploma
--   fapi_form_url_medal    → Medaile + diplom / RewardVariant.medalAndDiploma

alter table public.challenges
  add column if not exists fapi_form_url_diploma text;

alter table public.challenges
  add column if not exists fapi_form_url_medal text;
