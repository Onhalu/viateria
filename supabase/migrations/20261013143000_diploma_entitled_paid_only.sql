-- The reward stays locked until the FAPI purchase is paid.
-- A published diploma_price_cents of 0 and pricing_type = free no longer
-- entitle the diploma file. Apply this before relying on diploma_status.

CREATE OR REPLACE FUNCTION private.diploma_entitled(p_user_id uuid, p_challenge_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
           SELECT 1 FROM public.challenge_participations cp
            WHERE cp.user_id = p_user_id AND cp.challenge_id = p_challenge_id
              AND cp.status = 'completed')
     AND EXISTS (
           SELECT 1 FROM public.purchases pu
            WHERE pu.user_id = p_user_id AND pu.challenge_id = p_challenge_id
              AND pu.status = 'paid');
$$;

COMMENT ON FUNCTION private.diploma_entitled(uuid, uuid) IS
  'Full PNG entitlement: participation completed AND a paid purchase. A zero diploma price and pricing_type=free do not unlock the file.';

REVOKE ALL ON FUNCTION private.diploma_entitled(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.diploma_entitled(uuid, uuid) TO service_role;
