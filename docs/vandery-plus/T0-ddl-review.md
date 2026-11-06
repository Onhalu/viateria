# T0 — DBA review of VANDERY+ entitlement DDL

**SPEC:** §5, §6, §14.3, A2, A3, A5, A6. **Not applied** to any remote project.
Local/CI only. Prod migrate = Ask first. Staging apply = Ask first.

## Decision

The migration `20261106113000_vandery_plus_membership.sql` matches the approved table, with the constraints below. Scoring formula in `leaderboard_rows` / `get_leaderboard` / `get_my_score` is not modified. `verify_waypoint` is not modified.

## Schema

| Item | Review |
| --- | --- |
| One current row per user | Partial unique index on `user_id` where `anonymized_at is null` and `status` is a lifecycle status. Renew, cancel, refund, and a later repurchase update that row (A5 / P7). A second insert violates the index (DB-15). |
| `expires_at NOT NULL` | Pending checkout stores `now()` so the column is never null. `has_active_vandery_plus` still requires `status = 'active'` and `expires_at > now()`. |
| `cancel_at_period_end` | Does not turn off access before `expires_at` (DB-02). |
| Idempotency | `vandery_plus_webhook_events.idempotency_key` is the invoice id only (`20261106120100`). A retry classified as another kind does not extend `expires_at` again. |
| Hot lookup | Partial index `(user_id, expires_at) WHERE status = 'active' AND anonymized_at IS NULL` matches `has_active_vandery_plus`. |
| Status domain | Check constraint: `pending`, `active`, `expired`, `revoked`, `failed`. |

## Security (Supabase Postgres best practices)

- **RLS on**, no policy for INSERT, UPDATE, or DELETE for `authenticated` or `anon`. SELECT is `user_id = auth.uid()` only (DB-13, DB-14). A client cannot set `status = active`.
- **`service_role` / table owner bypass RLS.** That is the webhook path. The Flutter client never receives `service_role`.
- **`commit_vandery_plus_event` is `SECURITY DEFINER`**, `search_path = public`, `REVOKE` from `PUBLIC`, `anon`, and `authenticated`. Execute is granted to `service_role` only. The function refuses the write when `p_user_id` is not the row’s user (ED-12). The patch cannot change `user_id`. Status values are allow-listed.
- **`has_active_vandery_plus` is `SECURITY DEFINER` in `public`.** Supabase guidance prefers definer functions outside an exposed schema. This repo and SPEC §6 already put the same class of helper in `public` (`record_place_visit`, `get_leaderboard`). The function returns a boolean only, forces `search_path = public`, and returns false when the caller is not `service_role` and `p_uid` is not `auth.uid()`. It does not read `user_metadata`.
- **No view** over the membership table, so the security-invoker view rule does not apply.
- **Account delete (DB-16, §14.3 OQ3).** `BEFORE DELETE` on `profiles` anonymizes the membership row instead of cascading it away. `user_id` becomes null (tombstone), `anonymized_at` is set, `fapi_subscription_id` is cleared. Amount, currency, invoice id, and period timestamps stay as the accounting trace. The partial unique index ignores anonymized rows, so tombstones do not collide.

## DBA P1 / P2

`20261106120200_vandery_plus_dba_p1_p2.sql`:

- **P1.** `can_record_place_visit` is not executable by `authenticated`. The map and prefs RPCs are security definer and call it as the owner. Trigger functions `touch_vandery_plus_membership` and `anonymize_vandery_plus_before_profile_delete` are not executable by `anon` or `authenticated`.
- **P2.** `vandery_plus_memberships_select_own` uses `(select auth.uid()) = user_id` so the uid is planned once per statement.

## Map gate (A2)

`record_place_visit` and `record_place_visits_batch` raise `membership_required` (`P0001`) when `source = 'map'` and `has_active_vandery_plus()` is false.

The same predicate is in `place_visits` INSERT policy via `can_record_place_visit`, so a direct insert cannot skip the RPC.

`verify_waypoint` is untouched. It still inserts `place_visits.source = 'verify'` for an open or paid challenge without a membership (DB-09).

### `prefs_sync` (SPEC §6, Ask first — default applied)

A non-member may sync device visits only when they already have at least one `place_visits` row (challenge verifies already on the server). A brand-new non-member cannot seed the board through `prefs_sync`. A member can sync. This is the default in the SPEC; change it only with an explicit Ask.

### Map-gate guard

`20261106120000_record_place_visit_source_guard.sql` (rollback in `supabase/rollbacks/`, not applied):

- `can_record_place_visit('verify')` returns false.
- `record_place_visit` and `record_place_visits_batch` reject any source other than `map` and `prefs_sync` with `22023`.
- A direct INSERT of `source = verify` fails the INSERT policy.
- `verify_waypoint` still inserts `source = verify` itself.

`prefs_sync` is unchanged.

### Not changed

`ON DELETE CASCADE` on `purchases` and `challenge_diplomas` is a separate decision. This review does not change it.

## Webhook lifecycle (owned by the Edge reducer, committed here)

| Event | Effect |
| --- | --- |
| `paid_first` | `status = active`, `expires_at = now + 1 month`, subscription id stored. Replay: no second row, no second month. |
| `renew` | Same row, `expires_at + 1 month` once per invoice id, `cancel_at_period_end` cleared. |
| `cancel` | `cancel_at_period_end = true`, status stays `active` until `expires_at`. |
| `refund` | `status = revoked` immediately. |
| `payment_failed` | No activation and no extension. A `pending` row stays `pending`. An `active` row is left until `expires_at` (no grace — Legal §14.4 is still `[rozhodnout]`). |

Challenge invoices stay on `purchases`. This commit function never writes that table.

## Explicitly not in this review

- Prod apply, staging apply, Edge deploy, live FAPI product.
- Seed of thematic diplomas (P5). The diploma migration is an empty catalog.
- Leaderboard formula. Still `place_points + challenge_points`. One place, one point.
