-- =============================================================================
-- 0025_w2_verify_waypoint_catalog_view.sql       (SPEC §4 W2 – server)
-- READY FOR REPO – NOT APPLIED on prod (await Ondřej apply OK)  |  Viateria yzmbxxgesnbsqygzgdky
-- * verify_waypoint: SAME signature + JSON; promo gate (private.challenge_readable);
--   dual-write progress + participations; diploma issue on completion from template.
-- * Drops 0024 interim mirror. challenge_catalog_v (security_invoker).
-- * REVOKE EXECUTE on verify from PUBLIC/anon.
-- Requires 0021–0024. PREREQUISITE: 0018 (PR #36, merged to main as 3dccaa1) MUST be
-- applied on prod BEFORE this file (promo gate + public.challenge_readable wrapper for checkout).
-- 0018 is in repo history but NOT yet applied on prod as of 2026-10-06.
-- =============================================================================

DROP TRIGGER IF EXISTS challenge_progress_mirror ON public.challenge_progress;
DROP FUNCTION IF EXISTS private.mirror_challenge_progress();

INSERT INTO public.challenge_participations (id, user_id, challenge_id, status, joined_at, started_at, completed_at)
SELECT cp.id, cp.user_id, cp.challenge_id, cp.status, cp.started_at, cp.started_at,
       CASE WHEN cp.status = 'completed' THEN coalesce(cp.completed_at, cp.started_at) END
FROM public.challenge_progress cp
ON CONFLICT (user_id, challenge_id) DO UPDATE
  SET status = excluded.status,
      started_at = coalesce(public.challenge_participations.started_at, excluded.started_at),
      completed_at = excluded.completed_at;

CREATE OR REPLACE FUNCTION public.verify_waypoint(p_waypoint_id uuid, p_photo_path text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  uid uuid := auth.uid();
  wp public.waypoints%rowtype;
  ch public.challenges%rowtype;
  purchased boolean;
  prev_id uuid;
  prev_done boolean;
  remaining integer;
  next_wp_id uuid;
  next_step_id uuid;
  closing_step_id uuid;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if p_photo_path is null or length(trim(p_photo_path)) = 0 then
    raise exception 'photo required';
  end if;
  if p_photo_path not like uid::text || '/%' then
    raise exception 'invalid photo path';
  end if;

  select * into wp from public.waypoints where id = p_waypoint_id;
  if not found then
    raise exception 'waypoint not found';
  end if;

  select * into ch from public.challenges where id = wp.challenge_id;
  if not found or not private.challenge_readable(ch.id) then
    raise exception 'challenge not published';
  end if;

  purchased := ch.pricing_type = 'free' or exists (
    select 1 from public.purchases
    where user_id = uid and challenge_id = ch.id and status = 'paid'
  );
  if not purchased then
    raise exception 'purchase required';
  end if;

  if ch.access_mode = 'story' then
    select w.id into prev_id
    from public.waypoints w
    where w.challenge_id = ch.id and w.sort_order = wp.sort_order - 1;
    if prev_id is not null then
      select exists (
        select 1 from public.waypoint_progress
        where user_id = uid and waypoint_id = prev_id
      ) into prev_done;
      if not prev_done then
        raise exception 'previous waypoint incomplete';
      end if;
    end if;
  end if;

  insert into public.challenge_progress (user_id, challenge_id, status)
  values (uid, ch.id, 'in_progress')
  on conflict (user_id, challenge_id) do nothing;

  insert into public.challenge_participations (user_id, challenge_id, status, joined_at, started_at)
  values (uid, ch.id, 'in_progress', now(), now())
  on conflict (user_id, challenge_id) do update
    set status = case when public.challenge_participations.status = 'joined'
                      then 'in_progress' else public.challenge_participations.status end,
        started_at = coalesce(public.challenge_participations.started_at, now());

  insert into public.waypoint_progress (user_id, waypoint_id, photo_path)
  values (uid, p_waypoint_id, p_photo_path)
  on conflict (user_id, waypoint_id) do update
    set photo_path = excluded.photo_path, completed_at = now();

  select count(*) into remaining
  from public.waypoints w
  where w.challenge_id = ch.id
    and not exists (
      select 1 from public.waypoint_progress p
      where p.user_id = uid and p.waypoint_id = w.id
    );

  if remaining = 0 then
    update public.challenge_progress
       set status = 'completed', completed_at = coalesce(completed_at, now())
     where user_id = uid and challenge_id = ch.id;
    update public.challenge_participations
       set status = 'completed', completed_at = coalesce(completed_at, now())
     where user_id = uid and challenge_id = ch.id;
    begin
      perform private.issue_challenge_diploma(uid, ch.id);
    exception when others then
      raise warning 'verify_waypoint: diploma issue failed for % / %: %', uid, ch.id, sqlerrm;
    end;
  end if;

  insert into public.place_visits (user_id, place_id, source)
  values (uid, wp.place_id, 'verify')
  on conflict (user_id, place_id) do nothing;

  next_step_id := null;
  closing_step_id := null;
  next_wp_id := null;
  if ch.access_mode = 'story' then
    if remaining = 0 then
      select s.id into closing_step_id
      from public.challenge_story_steps s
      where s.challenge_id = ch.id and s.kind = 'closing'
      limit 1;
    else
      select w.id into next_wp_id
      from public.waypoints w
      where w.challenge_id = ch.id and w.sort_order = wp.sort_order + 1
      limit 1;
      if next_wp_id is not null then
        select s.id into next_step_id
        from public.challenge_story_steps s
        where s.challenge_id = ch.id and s.kind = 'before_waypoint' and s.waypoint_id = next_wp_id
        limit 1;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'remaining', remaining,
    'challenge_id', ch.id,
    'unlocked_waypoint_id', next_wp_id,
    'next_story_step_id', next_step_id,
    'closing_story_step_id', closing_step_id
  );
end;
$$;
COMMENT ON FUNCTION public.verify_waypoint(uuid, text) IS
  'Verifies a waypoint for auth.uid(). Promo gate via private.challenge_readable. Dual-writes progress + participations; issues diploma snapshot from template on completion.';
REVOKE EXECUTE ON FUNCTION public.verify_waypoint(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_waypoint(uuid, text) TO authenticated, service_role;

CREATE OR REPLACE VIEW public.challenge_catalog_v
WITH (security_invoker = true) AS
WITH me AS (
  SELECT coalesce((SELECT p.locale FROM public.profiles p WHERE p.id = (SELECT auth.uid())), 'cs') AS locale
)
SELECT c.id, c.slug, c.status, c.access_mode, c.pricing_type, c.country_code, c.region,
       c.difficulty, c.length, c.is_promo, c.cover_image_url, c.period_state,
       c.valid_from, c.valid_to, c.created_at, c.updated_at,
       me.locale AS resolved_for_locale,
       private.pick_locale(t.title_cs, t.title_en, t.title_de, me.locale) AS title,
       coalesce(private.pick_locale(d.desc_cs, d.desc_en, d.desc_de, me.locale), '') AS description,
       (SELECT dip.headline FROM public.challenge_diplomas dip
         WHERE dip.challenge_id = c.id AND dip.user_id IS NULL AND dip.status = 'published'
           AND now() <@ tstzrange(dip.valid_from, coalesce(dip.valid_to, 'infinity'::timestamptz), '[)')
         ORDER BY CASE dip.lang WHEN me.locale THEN 0 WHEN 'cs' THEN 1 WHEN 'en' THEN 2 ELSE 3 END
         LIMIT 1) AS diploma_headline,
       (SELECT dip.body FROM public.challenge_diplomas dip
         WHERE dip.challenge_id = c.id AND dip.user_id IS NULL AND dip.status = 'published'
           AND now() <@ tstzrange(dip.valid_from, coalesce(dip.valid_to, 'infinity'::timestamptz), '[)')
         ORDER BY CASE dip.lang WHEN me.locale THEN 0 WHEN 'cs' THEN 1 WHEN 'en' THEN 2 ELSE 3 END
         LIMIT 1) AS diploma_body,
       t.title_cs, t.title_en, t.title_de,
       d.desc_cs, d.desc_en, d.desc_de,
       pr.diploma_price_cents, pr.medal_price_cents, pr.currency,
       pr.vat_rate, pr.including_vat,
       pr.source AS price_source, pr.synced_at AS price_synced_at,
       public.challenge_sale_form_url(c.id, 'diploma', me.locale) AS fapi_form_url_diploma,
       public.challenge_sale_form_url(c.id, 'medal_and_diploma', me.locale) AS fapi_form_url_medal
FROM public.challenges c
CROSS JOIN me
LEFT JOIN public.challenge_titles t
  ON t.challenge_id = c.id AND t.status = 'published'
 AND now() <@ tstzrange(t.valid_from, coalesce(t.valid_to, 'infinity'::timestamptz), '[)')
LEFT JOIN public.challenge_descriptions d
  ON d.challenge_id = c.id AND d.status = 'published'
 AND now() <@ tstzrange(d.valid_from, coalesce(d.valid_to, 'infinity'::timestamptz), '[)')
LEFT JOIN public.challenge_prices pr
  ON pr.challenge_id = c.id AND pr.status = 'published'
 AND now() <@ tstzrange(pr.valid_from, coalesce(pr.valid_to, 'infinity'::timestamptz), '[)');
COMMENT ON VIEW public.challenge_catalog_v IS
  'Catalog/detail read model (SPEC §2.9). security_invoker. Diploma text from challenge_diplomas templates. Promo prices NOT applied (overlay via list_my_promos).';
REVOKE ALL ON public.challenge_catalog_v FROM anon;
GRANT SELECT ON public.challenge_catalog_v TO authenticated;

-- =============================================================================
-- ROLLBACK (manual)
-- =============================================================================
-- DROP VIEW IF EXISTS public.challenge_catalog_v;
-- -- restore verify_waypoint from _live_snapshot or PR #36 0018; re-create 0024 mirror
-- =============================================================================
