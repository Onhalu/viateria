/**
 * Supabase Auth "Send Email" hook secret.
 *
 * Dashboard value looks like `v1,whsec_<base64>`. standardwebhooks wants the
 * base64 portion. An empty result means the hook must fail closed.
 */
export function hookSecretBytes(raw: string | null | undefined): string | null {
  const stripped = (raw ?? "").replace("v1,whsec_", "");
  return stripped.length > 0 ? stripped : null;
}
