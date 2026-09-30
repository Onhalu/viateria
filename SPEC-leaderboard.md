# Leaderboard v1

Global all-time board. Live reads only (`get_leaderboard` / `get_my_score`). No offline score cache and no materialized view.

## Scoring

- **+1** for each distinct `place_visits` row. Primary key `(user_id, place_id)` dedupes.
- Completed challenge (`challenge_progress.status = 'completed'`), using `challenges.difficulty`:
  - `easy` or null → **+3**
  - `normal` (medium) → **+4**
  - `hard` → **+5**
- **Total** = place points + challenge points.
- Rank: higher total first, then earlier first `place_visits.visited_at`, then `user_id`. Users with 0 points are omitted. `get_my_score` still returns the caller, with rank, even outside the top 50.

## Visits

| Source | When |
|---|---|
| `map` | The signed-in user marks a place on the map (existing visited-places flow). |
| `verify` | `verify_waypoint` succeeds. After `0014_waypoints_place_id_required_verify.sql`, the visit is `waypoints.place_id` (no proximity search). Until that migration, `0011` records the nearest place within 50 m. |
| `prefs_sync` | One-shot upload of place ids still stored in device SharedPreferences. |

The score uses the server row, not a second local count.

Profile category cards and map visited markers read `VerifiedPlacesStore`. On cold start and on each auth login, after `bindUser`, the app loads the caller's `place_visits.place_id` rows (`fetchMyVisitedPlaceIds`, RLS select own, no service role) and unions them into that store. The prefs-sync flag does not skip this read. The prefs upload still runs afterward.

Migration `0012_backfill_place_visits_from_waypoints.sql` inserts `place_visits` from `waypoint_progress` (nearest place within 50 m, `source = verify`, `visited_at` from `completed_at`). `ON CONFLICT (user_id, place_id) DO NOTHING` keeps it idempotent. That migration is already applied on production; the file is the repo copy.

`0013_waypoints_place_id_nullable_backfill.sql` adds nullable `waypoints.place_id` and backfills the nearest place within 50 m. `0014` makes `place_id` required and points `verify_waypoint` at that id. Apply `0014` only when unmatched published waypoints = 0 (CMS-fix Zelená Hora `95f6584b-45be-4b57-9af8-12a10b2a2a2d` first).

## API

Migration: `supabase/migrations/0011_leaderboard.sql`. That file also ensures `challenges.difficulty` (nullable, `easy` / `normal` / `hard`) when the column is absent, same idempotent block as `0006_challenge_difficulty.sql`.

- Table `place_visits`. RLS: authenticated select/insert of **own** rows only.
- `record_place_visit(p_place_id, p_source)` — insert, ignore duplicates.
- `record_place_visits_batch(p_place_ids, p_source default 'prefs_sync')`.
- `get_leaderboard(p_limit default 50)` — limit clamped to ≤ 50. Columns: `user_id`, `display_name`, `avatar_url`, `total_points`, `place_points`, `challenge_points`, `rank`. `display_name` comes from `profiles` inside the RPC. Email is never selected.
- `get_my_score()` — same columns for `auth.uid()`.

Apply the migration before expecting the app RPCs to exist. Do not merge until an explicit **merge**.

## App

- Bottom nav fourth tab is **Profil** (`Icons.person_outline`). The welcome-header avatar also opens `/profile`. **Žebříček** is the welcome-header action (`Icons.military_tech_outlined`, outline). It opens a modal bottom sheet (~82% height, cream, forest barrier at 40%). The profile card opens the same sheet. Dismiss is the back arrow („Zavřít“) or a barrier tap. `/leaderboard` uses that same sheet, not a full-screen page.
- Under completed challenges: card **Žebříček** with `#rank · N bodů` or **Zatím bez bodů**, chevron opens the sheet.
- Colors stay on `BrandColors`. `shellFill` `#7D8B6A` is only the welcome header and the floating bottom nav.

Out of scope: per-challenge boards, seasons, region filter, opt-out, invented visit history, medal artwork.
