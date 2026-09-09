# Viateria

Gamified tourist challenges (SPEC v1). Hikers and cyclists pick a published challenge, follow OSM-mapped waypoints, verify each stop with a **live camera photo**, and earn a 9:16 diploma.

Catalog content is **not** hardcoded in the app. Challenges, waypoints, and promo stripes are authored in **Supabase** (`draft` | `published` | `archived`). The client only renders `published` rows.

## SPEC v1 (in scope)

- Challenge catalog: **open** (all waypoints after access) and **story** (next waypoint unlocks only after the previous is complete)
- Free / paid catalog; **Stripe Checkout** unlocks paid challenges
- **VerifyWaypoint v1**: live camera photo required, upload to Storage (no GPS)
- **RoutePlanner**: hike / bike, km, elevation, time, difficulty, OpenStreetMap link
- Promo stripe (same card chrome as a challenge card), DB-driven
- Diploma **9:16** with confetti and medals on complete
- Custom i18n: **cs / en / de**
- Secrets via environment — never committed
- **Mapa tab**: MapLibre OSM basemap, památky by type, search/filters/list/locate

## Out of scope

GPS verify, offline cache, Story Unlock Modal media, Open-Meteo, SOS, GPX export, leaderboards, regional stats map.

## Stack

Flutter, MapLibre (`maplibre_gl`) + OSM vector styles, Supabase (Auth, Postgres, Storage), Stripe, custom i18n.

## Setup

```bash
flutter pub get
cp .env.example .env   # fill SUPABASE_URL, SUPABASE_ANON_KEY, STRIPE_PUBLISHABLE_KEY
flutter run --dart-define-from-file=.env
```

Without env vars the app shows a configuration screen instead of inventing catalog content.

### Map style (`MAP_STYLE_URL`)

```bash
flutter run --dart-define=MAP_STYLE_URL=https://api.maptiler.com/maps/streets-v2/style.json?key=YOUR_KEY
# or:
flutter run --dart-define-from-file=.env
```

| Value | Basemap |
| --- | --- |
| Production MapTiler / Stadia / self-hosted style JSON | Use this before release |
| Empty / omitted | Non-prod fallback: `https://tiles.openfreemap.org/styles/liberty` |

**TODO before release:** set a production style URL. Do **not** use `https://tile.openstreetmap.org` as a raster CDN.

Code: `lib/map/map_style_config.dart`. Mock památky live in `assets/map/`.

### Supabase

Apply `supabase/migrations/0001_init.sql` (CLI: `supabase db push` or the SQL editor).

Tables: `profiles`, `challenges`, `challenge_i18n`, `waypoints`, `waypoint_i18n`, `challenge_progress`, `waypoint_progress`, `promo_stripes`, `promo_stripe_i18n`, `purchases`.

Author content in the dashboard. Only `status = published` is visible. Publish translations for `cs`, `en`, and `de`.

Edge functions:

- `create-checkout-session` — authenticated; creates a Stripe Checkout session for a paid published challenge
- `stripe-webhook` — marks `purchases.status = paid` on `checkout.session.completed`

Set function secrets: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, plus the standard Supabase keys.

Storage bucket: `waypoint-photos` (`{user_id}/{challenge_id}/{waypoint_id}/{uuid}.jpg`).

### Stripe

1. Create a product/price (optional: store `stripe_price_id` on the challenge; otherwise `price_cents` is used)
2. Deploy the two edge functions
3. Point the webhook at `/functions/v1/stripe-webhook`

## Tests

```bash
flutter analyze
flutter test
```

## Unlock rules

| Mode | After access |
| --- | --- |
| **open** | Every waypoint is available |
| **story** | Waypoint *n+1* unlocks only after waypoint *n* is verified |

Paid challenges require `purchases.status = paid`. The `verify_waypoint` RPC enforces photo path, access, and story order on the server.

## Project layout

```
lib/domain/          unlock rules, route planner, photo policy
lib/data/            Supabase repositories
lib/map/             MapLibre style, place catalog, search/filter
lib/l10n/            custom cs/en/de strings
lib/ui/              catalog, challenge, map, verify, diploma, settings
supabase/migrations  Postgres + RLS + Storage
supabase/functions   Stripe checkout + webhook
```
