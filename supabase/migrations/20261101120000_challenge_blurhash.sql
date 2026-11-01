-- Nullable BlurHash for challenge covers.
-- Existing rows stay null; clients show a skeleton until a hash is stored.
-- No backfill in this migration.

alter table public.challenges
  add column if not exists blurhash text;

comment on column public.challenges.blurhash is
  'BlurHash of cover_image_url. Null until hashed. Clients show a skeleton; this migration does not backfill.';

-- Append blurhash to the catalog read model. Column order of the existing
-- view is unchanged; the new column is last so CREATE OR REPLACE is valid.
create or replace view public.challenge_catalog_v
with (security_invoker = true) as
with me as (
  select coalesce((select p.locale from public.profiles p where p.id = (select auth.uid())), 'cs') as locale
)
select c.id, c.slug, c.status, c.access_mode, c.pricing_type, c.country_code, c.region,
       c.difficulty, c.length, c.is_promo, c.cover_image_url, c.period_state,
       c.valid_from, c.valid_to, c.created_at, c.updated_at,
       me.locale as resolved_for_locale,
       private.pick_locale(t.title_cs, t.title_en, t.title_de, me.locale) as title,
       coalesce(private.pick_locale(d.desc_cs, d.desc_en, d.desc_de, me.locale), '') as description,
       (select dip.headline from public.challenge_diplomas dip
         where dip.challenge_id = c.id and dip.user_id is null and dip.status = 'published'
           and now() <@ tstzrange(dip.valid_from, coalesce(dip.valid_to, 'infinity'::timestamptz), '[)')
         order by case dip.lang when me.locale then 0 when 'cs' then 1 when 'en' then 2 else 3 end
         limit 1) as diploma_headline,
       (select dip.body from public.challenge_diplomas dip
         where dip.challenge_id = c.id and dip.user_id is null and dip.status = 'published'
           and now() <@ tstzrange(dip.valid_from, coalesce(dip.valid_to, 'infinity'::timestamptz), '[)')
         order by case dip.lang when me.locale then 0 when 'cs' then 1 when 'en' then 2 else 3 end
         limit 1) as diploma_body,
       t.title_cs, t.title_en, t.title_de,
       d.desc_cs, d.desc_en, d.desc_de,
       pr.diploma_price_cents, pr.medal_price_cents, pr.currency,
       pr.vat_rate, pr.including_vat,
       pr.source as price_source, pr.synced_at as price_synced_at,
       public.challenge_sale_form_url(c.id, 'diploma', me.locale) as fapi_form_url_diploma,
       public.challenge_sale_form_url(c.id, 'medal_and_diploma', me.locale) as fapi_form_url_medal,
       c.blurhash
from public.challenges c
cross join me
left join public.challenge_titles t
  on t.challenge_id = c.id and t.status = 'published'
 and now() <@ tstzrange(t.valid_from, coalesce(t.valid_to, 'infinity'::timestamptz), '[)')
left join public.challenge_descriptions d
  on d.challenge_id = c.id and d.status = 'published'
 and now() <@ tstzrange(d.valid_from, coalesce(d.valid_to, 'infinity'::timestamptz), '[)')
left join public.challenge_prices pr
  on pr.challenge_id = c.id and pr.status = 'published'
 and now() <@ tstzrange(pr.valid_from, coalesce(pr.valid_to, 'infinity'::timestamptz), '[)');

comment on view public.challenge_catalog_v is
  'Catalog/detail read model (SPEC §2.9). security_invoker. Diploma text from challenge_diplomas templates. Promo prices NOT applied (overlay via list_my_promos). Includes challenges.blurhash.';

revoke all on public.challenge_catalog_v from anon;
grant select on public.challenge_catalog_v to authenticated;
