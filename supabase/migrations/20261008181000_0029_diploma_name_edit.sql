-- =============================================================================
-- 0029_diploma_name_edit.sql
-- NOT APPLIED. Do not run this on prod without an explicit OK from Ondřej.
-- Builds on prod diploma_status from 0028 (lazy issue, VOLATILE).
--
-- Until name_edited_at is set, diploma_status copies profiles.display_name
-- onto the issued row and reprints recipient_name_display (cs = accusative).
-- A profile rename therefore shows up on the next status/render.
-- public.edit_diploma_name stores the typed string verbatim, once, and does
-- not decline it again. The Edge hash already includes recipient_name_display,
-- so either change misses the PNG cache and re-renders. Layout is unchanged.
-- =============================================================================

ALTER TABLE public.challenge_diplomas
  ADD COLUMN IF NOT EXISTS name_edited_at timestamptz;

ALTER TABLE public.challenge_diplomas
  DROP CONSTRAINT IF EXISTS challenge_diplomas_name_edited_check;
ALTER TABLE public.challenge_diplomas
  ADD CONSTRAINT challenge_diplomas_name_edited_check
  CHECK (name_edited_at IS NULL OR recipient_name_display IS NOT NULL);

COMMENT ON COLUMN public.challenge_diplomas.recipient_name IS
  'Nominative snapshot. NULL name_edited_at: refreshed from profiles.display_name by diploma_status. After a one-time edit the printed form in recipient_name_display wins.';
COMMENT ON COLUMN public.challenge_diplomas.recipient_name_display IS
  'Printed name after "pro". While name_edited_at IS NULL, cs is private.cs_accusative(display_name) and en/de is the profile name. After edit_diploma_name it is the owner''s verbatim string and is not declined again.';
COMMENT ON COLUMN public.challenge_diplomas.name_edited_at IS
  'Set once by public.edit_diploma_name. NULL means the printed name still follows profiles.display_name.';

-- ---------------------------------------------------------------------------
-- diploma_status: 0028 body + live profile name, plus edit flags
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.diploma_status(p_challenge_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  d public.challenge_diplomas%ROWTYPE;
  v_state text;
  v_day text;
  v_profile text;
  v_display text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO d FROM public.challenge_diplomas
   WHERE challenge_id = p_challenge_id AND user_id = v_uid;
  IF d.id IS NULL AND EXISTS (
       SELECT 1 FROM public.challenge_participations cp
        WHERE cp.user_id = v_uid AND cp.challenge_id = p_challenge_id
          AND cp.status = 'completed') THEN
    BEGIN
      PERFORM private.issue_challenge_diploma(v_uid, p_challenge_id);
    EXCEPTION WHEN others THEN
      RAISE WARNING 'diploma_status: lazy issue failed for % / %: %',
        v_uid, p_challenge_id, SQLERRM;
    END;
    SELECT * INTO d FROM public.challenge_diplomas
     WHERE challenge_id = p_challenge_id AND user_id = v_uid;
  END IF;

  -- Non-edited diplomas follow the current profile name.
  IF d.id IS NOT NULL AND d.revoked_at IS NULL AND d.name_edited_at IS NULL THEN
    SELECT nullif(
             btrim(regexp_replace(coalesce(p.display_name, ''), '[[:cntrl:]]', '', 'g')),
             '')
      INTO v_profile
      FROM public.profiles p
     WHERE p.id = v_uid;
    IF v_profile IS NULL THEN
      v_display := NULL;
    ELSIF coalesce(d.lang, 'cs') = 'cs' THEN
      v_display := left(private.cs_accusative(v_profile), 80);
    ELSE
      v_display := left(v_profile, 80);
    END IF;
    IF d.recipient_name IS DISTINCT FROM v_profile
       OR d.recipient_name_display IS DISTINCT FROM v_display THEN
      UPDATE public.challenge_diplomas
         SET recipient_name = v_profile,
             recipient_name_display = v_display
       WHERE id = d.id;
      d.recipient_name := v_profile;
      d.recipient_name_display := v_display;
    END IF;
  END IF;

  IF d.completed_at IS NOT NULL THEN
    v_day := to_char((d.completed_at AT TIME ZONE 'Europe/Prague')::date, 'DD.MM.YYYY');
  END IF;
  v_state := CASE
    WHEN d.id IS NULL THEN 'locked'
    WHEN d.revoked_at IS NOT NULL THEN 'revoked'
    WHEN NOT private.diploma_entitled(v_uid, p_challenge_id) THEN 'buy'
    WHEN d.recipient_name_display IS NULL THEN 'need_name'
    WHEN d.image_path IS NULL THEN 'render'
    ELSE 'ready' END;
  RETURN jsonb_build_object(
    'state', v_state,
    'diploma_id', d.id,
    'lang', d.lang,
    'recipient_name_display', d.recipient_name_display,
    'completion_day_label', CASE WHEN v_day IS NULL THEN NULL
                                 ELSE 'dokončeno dne ' || v_day END,
    'completed_on', (d.completed_at AT TIME ZONE 'Europe/Prague')::date,
    'rendered_at', d.rendered_at,
    'name_editable', (d.id IS NOT NULL
                      AND d.revoked_at IS NULL
                      AND d.name_edited_at IS NULL
                      AND d.recipient_name_display IS NOT NULL),
    'name_source', CASE WHEN d.name_edited_at IS NOT NULL THEN 'edited'
                        ELSE 'profile' END);
END;
$$;
COMMENT ON FUNCTION public.diploma_status(uuid) IS
  'UI state for /diploma. Refreshes the printed name from profiles.display_name until name_edited_at is set. Exposes name_editable and name_source (profile|edited).';
REVOKE ALL ON FUNCTION public.diploma_status(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.diploma_status(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- One-time verbatim name. Authenticated owner only.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.edit_diploma_name(p_diploma_id uuid, p_name text)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  d public.challenge_diplomas%ROWTYPE;
  v_name text := btrim(p_name);
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF v_name IS NULL
     OR char_length(v_name) < 1
     OR char_length(v_name) > 40
     OR v_name ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'invalid diploma name' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO d
    FROM public.challenge_diplomas
   WHERE id = p_diploma_id AND user_id = v_uid
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'diploma not found' USING ERRCODE = 'P0002';
  END IF;
  IF d.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'diploma revoked' USING ERRCODE = '42501';
  END IF;
  IF d.name_edited_at IS NOT NULL THEN
    RAISE EXCEPTION 'diploma name already edited' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.challenge_diplomas
     SET recipient_name_display = v_name,
         name_edited_at = now()
   WHERE id = d.id;

  RETURN public.diploma_status(d.challenge_id);
END;
$$;
COMMENT ON FUNCTION public.edit_diploma_name(uuid, text) IS
  'One-time owner edit of the printed diploma name. Stores p_name verbatim (no declension), sets name_edited_at, and returns diploma_status.';
REVOKE ALL ON FUNCTION public.edit_diploma_name(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.edit_diploma_name(uuid, text) TO authenticated;
