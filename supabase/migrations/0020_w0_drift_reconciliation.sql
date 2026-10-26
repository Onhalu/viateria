-- =============================================================================
-- 0020_w0_drift_reconciliation.sql            (SPEC-challenge-architecture §4 W0)
-- ALREADY APPLIED ON PROD yzmbxxgesnbsqygzgdky (Postgres 17).
-- History version 20261005125735, applied 2026-10-05. Do not re-apply.
-- Do not renumber: draft PRs #34/#35/#36 hold migrations 0016–0019.
-- Purpose: bring prod and repo `main` into agreement BEFORE the redesign expand.
-- SPEC v2 (Ondřej 2026-10-05): UNIQUE (user_id, challenge_id) STAYS — user buys
-- either diploma OR medal_and_diploma (one purchase per challenge). Only ADD
-- reward_variant, fapi_invoice_id UNIQUE, fapi_client_id (+ profiles.fapi_client_id).
-- Live facts verified 2026-10-05 (read-only):
--   * purchases.reward_variant MISSING on prod (repo 0002 never applied)  → added here
--   * challenges.stripe_price_id_diploma/_medal MISSING → NOT added (Flutter stops reading)
--   * diploma_price_cents NOT NULL DEFAULT 0 on prod → normalised to prod shape
--   * story tables on prod via timestamp migrations → asserted, not re-created
--   * purchases 0 rows
-- RELEASE COUPLING: deploy edge with this migration (PLAN.md §D):
--   start-fapi-checkout keeps onConflict 'user_id,challenge_id' but MUST check upsert error
--   (column now exists). fapi-webhook: store invoice fields; upgrade diploma→medal
--   semantics = open question (update row vs reject).
-- =============================================================================

DO $$
BEGIN
  IF to_regclass('public.challenge_story_steps') IS NULL
     OR to_regclass('public.challenge_story_step_i18n') IS NULL THEN
    RAISE EXCEPTION 'W0: story tables missing – apply 0016/0017 (PR #34) first';
  END IF;
END $$;

-- 1) purchases.reward_variant
ALTER TABLE public.purchases ADD COLUMN IF NOT EXISTS reward_variant text;
UPDATE public.purchases SET reward_variant = 'diploma' WHERE reward_variant IS NULL;
ALTER TABLE public.purchases ALTER COLUMN reward_variant SET DEFAULT 'diploma';
ALTER TABLE public.purchases ALTER COLUMN reward_variant SET NOT NULL;
ALTER TABLE public.purchases DROP CONSTRAINT IF EXISTS purchases_reward_variant_check;
ALTER TABLE public.purchases ADD CONSTRAINT purchases_reward_variant_check
  CHECK (reward_variant = ANY (ARRAY['diploma', 'medal_and_diploma']));
COMMENT ON COLUMN public.purchases.reward_variant IS
  'diploma | medal_and_diploma. UNIQUE (user_id, challenge_id) stays — one purchase per challenge.';

-- 2) Keep UNIQUE (user_id, challenge_id); add FK index for challenge_id
-- (unique already leads with user_id; challenge_id alone was unindexed)
CREATE INDEX IF NOT EXISTS purchases_challenge_idx ON public.purchases (challenge_id);

-- 3) FAPI references
ALTER TABLE public.purchases ADD COLUMN IF NOT EXISTS fapi_invoice_id text;
ALTER TABLE public.purchases ADD COLUMN IF NOT EXISTS fapi_client_id text;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                 WHERE conrelid = 'public.purchases'::regclass
                   AND conname = 'purchases_fapi_invoice_id_key') THEN
    ALTER TABLE public.purchases ADD CONSTRAINT purchases_fapi_invoice_id_key UNIQUE (fapi_invoice_id);
  END IF;
END $$;
COMMENT ON COLUMN public.purchases.fapi_invoice_id IS
  'FAPI invoice id. UNIQUE → webhook replay cannot double-apply.';
COMMENT ON COLUMN public.purchases.amount_cents IS
  'Amount actually paid, taken from the FAPI invoice by fapi-webhook (not from the pending row).';

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fapi_client_id text;
CREATE UNIQUE INDEX IF NOT EXISTS profiles_fapi_client_id_uidx
  ON public.profiles (fapi_client_id) WHERE fapi_client_id IS NOT NULL;
COMMENT ON COLUMN public.profiles.fapi_client_id IS
  'FAPI client id = customer link (no separate customers table). Filled by fapi-webhook.';

-- 4) diploma_price_cents nullability → prod shape
UPDATE public.challenges SET diploma_price_cents = coalesce(price_cents, 0)
 WHERE diploma_price_cents IS NULL;
ALTER TABLE public.challenges ALTER COLUMN diploma_price_cents SET DEFAULT 0;
ALTER TABLE public.challenges ALTER COLUMN diploma_price_cents SET NOT NULL;

-- stripe_price_id_diploma / _medal: intentionally NOT added (SPEC W0). Dropped in W4 if present.

-- 5) Own-row policy in initplan form
DROP POLICY IF EXISTS "own purchases readable" ON public.purchases;
CREATE POLICY "own purchases readable" ON public.purchases
  FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

-- 6) Migration history: supabase migration repair / write story into repo (PLAN.md §E W0)

-- =============================================================================
-- ROLLBACK (manual; roll edge functions back FIRST)
-- =============================================================================
-- ALTER TABLE public.purchases DROP CONSTRAINT IF EXISTS purchases_fapi_invoice_id_key;
-- ALTER TABLE public.purchases DROP COLUMN IF EXISTS fapi_invoice_id, DROP COLUMN IF EXISTS fapi_client_id;
-- DROP INDEX IF EXISTS public.purchases_challenge_idx, public.profiles_fapi_client_id_uidx;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS fapi_client_id;
-- -- Keep purchases.reward_variant: edge functions on main already write it.
-- =============================================================================
