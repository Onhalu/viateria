-- =============================================================================
-- 0024_w1_participations_diplomas.sql            (SPEC §4 W1 – expand, part 4)
-- READY FOR REPO – NOT APPLIED on prod (await Ondřej apply OK)  |  Viateria yzmbxxgesnbsqygzgdky
-- challenge_participations (SPEC §2.7) – future SoT of participation/duration.
-- challenge_diplomas (SPEC §2.8 v2) – ONE table, two row kinds:
--   * TEMPLATE  user_id IS NULL: lang, headline, body, status, valid_from/to;
--     EXCLUDE one published per (challenge_id, lang) over overlapping windows.
--   * ISSUED    user_id NOT NULL: template_id + snapshot; issued_at / revoked_at;
--     partial UNIQUE (challenge_id, user_id) WHERE user_id IS NOT NULL.
-- Backfill templates from challenge_i18n.diploma_* (today all NULL → 0 rows OK).
-- Interim mirror from challenge_progress until 0025 dual-write.
-- =============================================================================

-- 1) challenge_participations
CREATE TABLE IF NOT EXISTS public.challenge_participations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  challenge_id uuid NOT NULL REFERENCES public.challenges (id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'joined'
    CHECK (status = ANY (ARRAY['joined', 'in_progress', 'completed'])),
  joined_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz,
  completed_at timestamptz,
  duration interval GENERATED ALWAYS AS (completed_at - started_at) STORED,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT challenge_participations_user_challenge_key UNIQUE (user_id, challenge_id),
  CONSTRAINT challenge_participations_shape CHECK (
       (status = 'joined'      AND started_at IS NULL AND completed_at IS NULL)
    OR (status = 'in_progress' AND started_at IS NOT NULL AND completed_at IS NULL)
    OR (status = 'completed'   AND started_at IS NOT NULL AND completed_at IS NOT NULL)),
  CONSTRAINT challenge_participations_order CHECK (
    (started_at IS NULL OR started_at >= joined_at - interval '1 second')
    AND (completed_at IS NULL OR completed_at >= started_at))
);
COMMENT ON TABLE public.challenge_participations IS
  'User↔challenge participation (SPEC §2.7). SoT for joined/started/completed and duration.';
CREATE INDEX IF NOT EXISTS challenge_participations_challenge_idx
  ON public.challenge_participations (challenge_id);
CREATE INDEX IF NOT EXISTS challenge_participations_completed_user_idx
  ON public.challenge_participations (user_id) WHERE status = 'completed';
DROP TRIGGER IF EXISTS challenge_participations_touch ON public.challenge_participations;
CREATE TRIGGER challenge_participations_touch BEFORE UPDATE ON public.challenge_participations
  FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();

INSERT INTO public.challenge_participations (id, user_id, challenge_id, status, joined_at, started_at, completed_at, created_at)
SELECT cp.id, cp.user_id, cp.challenge_id, cp.status, cp.started_at, cp.started_at,
       CASE WHEN cp.status = 'completed' THEN coalesce(cp.completed_at, cp.started_at) END,
       cp.started_at
FROM public.challenge_progress cp
ON CONFLICT (user_id, challenge_id) DO NOTHING;

CREATE OR REPLACE FUNCTION private.mirror_challenge_progress()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.challenge_participations
     WHERE user_id = OLD.user_id AND challenge_id = OLD.challenge_id;
    RETURN NULL;
  END IF;
  INSERT INTO public.challenge_participations (id, user_id, challenge_id, status, joined_at, started_at, completed_at)
  VALUES (NEW.id, NEW.user_id, NEW.challenge_id, NEW.status, NEW.started_at, NEW.started_at,
          CASE WHEN NEW.status = 'completed' THEN coalesce(NEW.completed_at, now()) END)
  ON CONFLICT (user_id, challenge_id) DO UPDATE
    SET status = excluded.status,
        started_at = coalesce(public.challenge_participations.started_at, excluded.started_at),
        completed_at = excluded.completed_at;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION private.mirror_challenge_progress() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS challenge_progress_mirror ON public.challenge_progress;
CREATE TRIGGER challenge_progress_mirror
  AFTER INSERT OR UPDATE OR DELETE ON public.challenge_progress
  FOR EACH ROW EXECUTE FUNCTION private.mirror_challenge_progress();

-- 2) challenge_diplomas – templates + issued in one table
CREATE TABLE IF NOT EXISTS public.challenge_diplomas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL REFERENCES public.challenges (id) ON DELETE RESTRICT,
  -- NULL = template; NOT NULL = issued (customer = profiles.id)
  user_id uuid REFERENCES public.profiles (id) ON DELETE CASCADE,
  template_id uuid REFERENCES public.challenge_diplomas (id) ON DELETE SET NULL,
  lang text NOT NULL CHECK (lang = ANY (ARRAY['cs', 'en', 'de'])),
  headline text NOT NULL,
  body text NOT NULL DEFAULT '',
  -- Template versioning (NULL on issued rows)
  status text CHECK (status IS NULL OR status = ANY (ARRAY['draft', 'published', 'archived'])),
  valid_from timestamptz,
  valid_to timestamptz,
  -- Issued snapshot fields (NULL on templates)
  participation_id uuid REFERENCES public.challenge_participations (id) ON DELETE SET NULL,
  recipient_name text,
  challenge_title text,
  completed_at timestamptz,
  duration interval,
  reward_variant text CHECK (reward_variant IS NULL OR reward_variant = ANY (ARRAY['diploma', 'medal_and_diploma'])),
  purchase_id uuid REFERENCES public.purchases (id) ON DELETE SET NULL,
  issued_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT challenge_diplomas_kind CHECK (
    (user_id IS NULL
       AND status IS NOT NULL AND valid_from IS NOT NULL
       AND template_id IS NULL AND participation_id IS NULL
       AND challenge_title IS NULL AND completed_at IS NULL
       AND issued_at IS NULL AND revoked_at IS NULL
       AND recipient_name IS NULL AND purchase_id IS NULL AND reward_variant IS NULL)
    OR
    (user_id IS NOT NULL
       AND issued_at IS NOT NULL AND challenge_title IS NOT NULL AND completed_at IS NOT NULL
       AND status IS NULL AND valid_from IS NULL AND valid_to IS NULL)
  ),
  CONSTRAINT challenge_diplomas_valid_range CHECK (
    valid_to IS NULL OR valid_from IS NULL OR valid_to > valid_from),
  CONSTRAINT challenge_diplomas_revoked_after CHECK (
    revoked_at IS NULL OR (issued_at IS NOT NULL AND revoked_at >= issued_at)),
  CONSTRAINT challenge_diplomas_one_published_template EXCLUDE USING gist (
    challenge_id WITH =,
    lang WITH =,
    tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)') WITH &&
  ) WHERE (status = 'published' AND user_id IS NULL)
);

-- If an earlier v1 draft created NOT NULL user_id / UNIQUE (challenge_id,user_id), rebuild constraints
DO $$
BEGIN
  -- Drop v1 full UNIQUE if present
  IF EXISTS (SELECT 1 FROM pg_constraint
             WHERE conrelid = 'public.challenge_diplomas'::regclass
               AND conname = 'challenge_diplomas_challenge_user_key') THEN
    ALTER TABLE public.challenge_diplomas DROP CONSTRAINT challenge_diplomas_challenge_user_key;
  END IF;
  -- Allow nullable user_id if v1 made it NOT NULL
  BEGIN
    ALTER TABLE public.challenge_diplomas ALTER COLUMN user_id DROP NOT NULL;
  EXCEPTION WHEN others THEN NULL;
  END;
  BEGIN
    ALTER TABLE public.challenge_diplomas ALTER COLUMN issued_at DROP NOT NULL;
  EXCEPTION WHEN others THEN NULL;
  END;
  BEGIN
    ALTER TABLE public.challenge_diplomas ALTER COLUMN challenge_title DROP NOT NULL;
  EXCEPTION WHEN others THEN NULL;
  END;
  BEGIN
    ALTER TABLE public.challenge_diplomas ALTER COLUMN completed_at DROP NOT NULL;
  EXCEPTION WHEN others THEN NULL;
  END;
END $$;

ALTER TABLE public.challenge_diplomas ADD COLUMN IF NOT EXISTS template_id uuid
  REFERENCES public.challenge_diplomas (id) ON DELETE SET NULL;
ALTER TABLE public.challenge_diplomas ADD COLUMN IF NOT EXISTS status text;
ALTER TABLE public.challenge_diplomas ADD COLUMN IF NOT EXISTS valid_from timestamptz;
ALTER TABLE public.challenge_diplomas ADD COLUMN IF NOT EXISTS valid_to timestamptz;
ALTER TABLE public.challenge_diplomas ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS challenge_diplomas_issued_uidx
  ON public.challenge_diplomas (challenge_id, user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS challenge_diplomas_templates_idx
  ON public.challenge_diplomas (challenge_id, lang, valid_from DESC) WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS challenge_diplomas_user_idx
  ON public.challenge_diplomas (user_id, issued_at DESC) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS challenge_diplomas_participation_idx
  ON public.challenge_diplomas (participation_id) WHERE participation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS challenge_diplomas_purchase_idx
  ON public.challenge_diplomas (purchase_id) WHERE purchase_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS challenge_diplomas_template_id_idx
  ON public.challenge_diplomas (template_id) WHERE template_id IS NOT NULL;

COMMENT ON TABLE public.challenge_diplomas IS
  'Diagram "diplomas". Templates (user_id IS NULL) hold diploma text per lang with versioning; issued rows (user_id set) are immutable snapshots with template_id + issued_at/revoked_at.';

DROP TRIGGER IF EXISTS challenge_diplomas_touch ON public.challenge_diplomas;
CREATE TRIGGER challenge_diplomas_touch BEFORE UPDATE ON public.challenge_diplomas
  FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();

-- Backfill templates from challenge_i18n (skip langs where both headline and body are NULL/blank)
INSERT INTO public.challenge_diplomas (
  challenge_id, user_id, lang, headline, body, status, valid_from)
SELECT i.challenge_id, NULL, i.locale,
       coalesce(nullif(btrim(i.diploma_headline), ''), nullif(btrim(i.diploma_body), ''), 'Diplom'),
       coalesce(i.diploma_body, ''),
       'published', c.created_at
FROM public.challenge_i18n i
JOIN public.challenges c ON c.id = i.challenge_id
WHERE (nullif(btrim(i.diploma_headline), '') IS NOT NULL
    OR nullif(btrim(i.diploma_body), '') IS NOT NULL)
  AND NOT EXISTS (
    SELECT 1 FROM public.challenge_diplomas d
     WHERE d.challenge_id = i.challenge_id AND d.user_id IS NULL AND d.lang = i.locale);

-- Sync diploma_* on challenge_i18n whenever templates change
CREATE OR REPLACE FUNCTION private.trg_refresh_legacy_diploma_templates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Only templates (user_id IS NULL) affect challenge_i18n.diploma_*
  IF TG_OP = 'DELETE' THEN
    IF OLD.user_id IS NULL THEN
      PERFORM private.refresh_legacy_challenge_i18n(OLD.challenge_id);
    END IF;
    RETURN NULL;
  END IF;
  IF NEW.user_id IS NULL OR (TG_OP = 'UPDATE' AND OLD.user_id IS NULL) THEN
    PERFORM private.refresh_legacy_challenge_i18n(NEW.challenge_id);
  END IF;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION private.trg_refresh_legacy_diploma_templates() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS challenge_diplomas_legacy_sync ON public.challenge_diplomas;
CREATE TRIGGER challenge_diplomas_legacy_sync
  AFTER INSERT OR UPDATE OR DELETE ON public.challenge_diplomas
  FOR EACH ROW EXECUTE FUNCTION private.trg_refresh_legacy_diploma_templates();

-- Issue (idempotent). Snapshot from published template; lang = profiles.locale → cs → en → de.
CREATE OR REPLACE FUNCTION private.issue_challenge_diploma(p_user_id uuid, p_challenge_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_part public.challenge_participations%ROWTYPE;
  v_lang text;
  v_title text;
  v_tmpl public.challenge_diplomas%ROWTYPE;
  v_purchase_id uuid;
  v_variant text;
  v_id uuid;
BEGIN
  SELECT id INTO v_id FROM public.challenge_diplomas
   WHERE challenge_id = p_challenge_id AND user_id = p_user_id;
  IF FOUND THEN
    RETURN v_id;
  END IF;

  SELECT * INTO v_part FROM public.challenge_participations
   WHERE user_id = p_user_id AND challenge_id = p_challenge_id AND status = 'completed';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'challenge not completed';
  END IF;

  SELECT coalesce(locale, 'cs') INTO v_lang FROM public.profiles WHERE id = p_user_id;
  v_lang := coalesce(v_lang, 'cs');

  SELECT private.pick_locale(t.title_cs, t.title_en, t.title_de, v_lang) INTO v_title
    FROM public.challenge_titles t
   WHERE t.challenge_id = p_challenge_id AND t.status = 'published'
     AND now() <@ tstzrange(t.valid_from, coalesce(t.valid_to, 'infinity'::timestamptz), '[)')
   LIMIT 1;

  SELECT d.* INTO v_tmpl
    FROM public.challenge_diplomas d
   WHERE d.challenge_id = p_challenge_id AND d.user_id IS NULL AND d.status = 'published'
     AND now() <@ tstzrange(d.valid_from, coalesce(d.valid_to, 'infinity'::timestamptz), '[)')
   ORDER BY CASE d.lang WHEN v_lang THEN 0 WHEN 'cs' THEN 1 WHEN 'en' THEN 2 ELSE 3 END
   LIMIT 1;

  SELECT id, reward_variant INTO v_purchase_id, v_variant FROM public.purchases
   WHERE user_id = p_user_id AND challenge_id = p_challenge_id AND status = 'paid'
   ORDER BY paid_at DESC NULLS LAST
   LIMIT 1;

  INSERT INTO public.challenge_diplomas (
    challenge_id, user_id, template_id, participation_id, lang, headline, body,
    recipient_name, challenge_title, completed_at, duration, reward_variant, purchase_id, issued_at)
  VALUES (
    p_challenge_id, p_user_id, v_tmpl.id, v_part.id,
    coalesce(v_tmpl.lang, v_lang),
    coalesce(nullif(btrim(v_tmpl.headline), ''), v_title, 'Diplom'),
    coalesce(v_tmpl.body, ''),
    (SELECT display_name FROM public.profiles WHERE id = p_user_id),
    coalesce(v_title, ''), v_part.completed_at, v_part.duration, v_variant, v_purchase_id, now())
  ON CONFLICT (challenge_id, user_id) WHERE (user_id IS NOT NULL) DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    SELECT id INTO v_id FROM public.challenge_diplomas
     WHERE challenge_id = p_challenge_id AND user_id = p_user_id;
  END IF;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION private.issue_challenge_diploma(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.issue_challenge_diploma(uuid, uuid) TO service_role;

-- 3) RLS
ALTER TABLE public.challenge_participations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_diplomas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own participations readable" ON public.challenge_participations;
CREATE POLICY "own participations readable" ON public.challenge_participations
  FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "own diplomas readable" ON public.challenge_diplomas;
DROP POLICY IF EXISTS "published diploma templates of readable challenges" ON public.challenge_diplomas;
DROP POLICY IF EXISTS "own issued diplomas readable" ON public.challenge_diplomas;
CREATE POLICY "published diploma templates of readable challenges" ON public.challenge_diplomas
  FOR SELECT TO authenticated
  USING (user_id IS NULL AND status = 'published' AND private.challenge_readable(challenge_id));
CREATE POLICY "own issued diplomas readable" ON public.challenge_diplomas
  FOR SELECT TO authenticated
  USING (user_id IS NOT NULL AND user_id = (SELECT auth.uid()));

REVOKE ALL ON public.challenge_participations, public.challenge_diplomas FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE
  ON public.challenge_participations, public.challenge_diplomas FROM authenticated;
GRANT SELECT ON public.challenge_participations, public.challenge_diplomas TO authenticated;

DROP POLICY IF EXISTS "own progress readable" ON public.challenge_progress;
CREATE POLICY "own progress readable" ON public.challenge_progress
  FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS "own waypoint progress readable" ON public.waypoint_progress;
CREATE POLICY "own waypoint progress readable" ON public.waypoint_progress
  FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));
CREATE INDEX IF NOT EXISTS challenge_progress_challenge_idx ON public.challenge_progress (challenge_id);

-- =============================================================================
-- ROLLBACK (manual)
-- =============================================================================
-- DROP FUNCTION IF EXISTS private.issue_challenge_diploma(uuid, uuid);
-- DROP TABLE IF EXISTS public.challenge_diplomas;
-- DROP TRIGGER IF EXISTS challenge_progress_mirror ON public.challenge_progress;
-- DROP FUNCTION IF EXISTS private.mirror_challenge_progress();
-- DROP TABLE IF EXISTS public.challenge_participations;
-- DROP INDEX IF EXISTS public.challenge_progress_challenge_idx;
-- =============================================================================
