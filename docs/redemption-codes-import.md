# Import challenge redemption codes

SPEC: `SPEC-challenge-redemption-codes` (SCHVÁLENO 2026-11-05, OQ-R1–R10 LOCK).

Codes from vyšlápni.cz orders become rows in `public.challenge_redemption_codes`. The database stores a SHA-256 hash, not the code. The app redeems through the Edge function `redeem-challenge-code`. There is no admin screen.

**Ask first before running this against production.** Do not apply the migration or this SQL as part of the implementation PR, and do not deploy the Edge function until that is explicitly approved. Do not commit the source CSV.

## CSV

Header row, UTF-8:

```text
challenge_id,code,buyer_email,expires_at
```

`expires_at` is optional. Empty means no expiry.

| Column | Rule |
| --- | --- |
| `challenge_id` | UUID of the open, paid, published challenge |
| `code` | 8–16 of `A–Z` and `0–9` after normalize |
| `buyer_email` | Folded with `lower(trim)` on insert. Must match the account email at redeem |
| `expires_at` | ISO timestamp, or empty |

Normalize (same as the app and the Edge function): trim, uppercase, remove spaces and `-`. `ab12-cd34` and `AB12 CD34` are the same code.

Several codes for the same email and challenge are allowed. Two identical codes for one challenge are not.

## Generate SQL

The script does not open a database connection.

```bash
python3 scripts/import_redemption_codes.py orders.csv > redeem.sql
```

Review `redeem.sql`. It contains `code_hash`, a 4-character `code_hint`, and the folded email. It does not contain the code. Then run it as a role that bypasses RLS (`service_role` or the Supabase SQL editor as the table owner). The `authenticated` role cannot insert.

```sql
-- after the insert, still as the owner / service role
select count(*) from public.challenge_redemption_codes
where challenge_id = '<uuid>' and redeemed_at is null;
```

`python3 scripts/import_redemption_codes.py --self-test` checks the shared SHA-256 vector for `AB12CD34`.

## Smoke after a staging insert

Do this on staging, not by deploying from the PR.

1. Sign in as the buyer email. Open the challenge. The medal button is **Mám kód**. The diploma button still opens FAPI.
2. Redeem the code once. `purchases.status` becomes `paid`, `reward_variant` is `medal_and_diploma`, `amount_cents` is 0. The code row has `redeemed_at`, `redeemed_by`, and `purchase_id`.
3. Redeem the same code again: `already_redeemed`.
4. A different account: `email_mismatch`, and `redeemed_at` stays null.
5. An account that already has `purchases.status = paid` for that challenge: `already_unlocked`, and the code stays unused.
6. A code imported for a different `challenge_id`: `challenge_mismatch`.
7. Eleven attempts in 15 minutes from one user: `rate_limited`.
8. As `authenticated`, `select` from `challenge_redemption_codes` returns no rows.
