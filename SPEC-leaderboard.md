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
| `verify` | `verify_waypoint` succeeds and a `places` row is within **50 m** of the waypoint. Nearest row only. |
| `prefs_sync` | One-shot upload of place ids still stored in device SharedPreferences. |

The score uses the server row, not a second local count.

## API

Migration: `supabase/migrations/0011_leaderboard.sql`.

- Table `place_visits`. RLS: authenticated select/insert of **own** rows only.
- `record_place_visit(p_place_id, p_source)` — insert, ignore duplicates.
- `record_place_visits_batch(p_place_ids, p_source default 'prefs_sync')`.
- `get_leaderboard(p_limit default 50)` — limit clamped to ≤ 50. Columns: `user_id`, `display_name`, `avatar_url`, `total_points`, `place_points`, `challenge_points`, `rank`. `display_name` comes from `profiles` inside the RPC. Email is never selected.
- `get_my_score()` — same columns for `auth.uid()`.

Apply the migration before expecting the app RPCs to exist. Do not merge until an explicit **merge**.

## App

- Bottom nav: Profil tab removed. **Žebříček** uses `Icons.military_tech_outlined` (outline).
- Welcome-header avatar opens Profile. Profile stays off the tab bar.
- Under completed challenges: card **Žebříček** with `#rank · N bodů` or **Zatím bez bodů**, chevron opens the board.
- Colors stay on `BrandColors`. `shellFill` `#7D8B6A` is only the welcome header and the floating bottom nav.

Out of scope: per-challenge boards, seasons, region filter, opt-out, invented visit history, medal artwork.
