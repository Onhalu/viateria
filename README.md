# Viateria

Gamified tourist challenges (SPEC v1). Hikers and cyclists pick a published challenge, follow OSM-mapped waypoints, verify each stop with a **live camera photo**, and earn a 9:16 diploma.

Catalog content is **not** hardcoded in the app. Challenges, waypoints, and promo stripes are authored in **Supabase** (`draft` | `published` | `archived`). The client only renders `published` rows.

## SPEC v1 (in scope)

- Challenge catalog: **open** (all waypoints after access) and **story** (next waypoint unlocks only after the previous is complete)
- Free / paid catalog; **FAPI sales forms** unlock paid challenges (Stripe edge functions remain unused by the CTA)
- **VerifyWaypoint**: GPS within 120 m, otherwise a **live camera photo**
- **RoutePlanner**: hike / bike, km, elevation, time, difficulty, OpenStreetMap link
- Promo stripe (same card chrome as a challenge card), DB-driven
- Diploma **9:16** with confetti and medals on complete
- Custom i18n: **cs / en / de**
- Secrets via environment — never committed
- **Mapa tab**: MapLibre OSM basemap, památky by type, search/filters/list/locate

## Out of scope

Offline cache, Story Unlock Modal media, Open-Meteo, SOS, GPX export, leaderboards, regional stats map.

## Stack

Flutter, MapLibre (`maplibre_gl`) + OSM vector styles, Supabase (Auth, Postgres, Storage), FAPI sales forms, custom i18n.

## Setup

```bash
flutter pub get
cp .env.example .env   # fill SUPABASE_URL, SUPABASE_ANON_KEY, STRIPE_PUBLISHABLE_KEY (legacy)
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

Code: `lib/map/map_style_config.dart`. Mock památky (167 places) live in `assets/map/pois.geojson`.

### Supabase

Apply `supabase/migrations/0001_init.sql` (CLI: `supabase db push` or the SQL editor).

Tables: `profiles`, `challenges`, `challenge_i18n`, `waypoints`, `waypoint_i18n`, `challenge_progress`, `waypoint_progress`, `promo_stripes`, `promo_stripe_i18n`, `purchases`.

Author content in the dashboard. Only `status = published` is visible. Publish translations for `cs`, `en`, and `de`.

Edge functions:

- `start-fapi-checkout` — authenticated; upserts a pending purchase and returns the FAPI form URL for the chosen reward variant
- `fapi-webhook` — marks `purchases.status = paid` on a verified FAPI paid-invoice notification
- `create-checkout-session` / `stripe-webhook` — leftover Stripe path; not used by the Flutter pay CTAs

Set function secrets: `FAPI_API_USERNAME`, `FAPI_API_KEY`, optional `FAPI_WEBHOOK_SECURITY` and `FAPI_CUSTOM_FIELD_ID_*`. Details: `supabase/functions/fapi-webhook/README.md`. Legacy Stripe secrets stay documented for the unused functions: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`.

Storage bucket: `waypoint-photos` (`{user_id}/{challenge_id}/{waypoint_id}/{uuid}.jpg`).

### FAPI

1. Create two sales forms in FAPI (digital diploma, medal + diploma). Do not invent URLs in the repo — paste each public form-page URL into `challenges.fapi_form_url_diploma` / `fapi_form_url_medal` when ready. A null/empty URL disables that pay CTA.
2. Create custom fields named `user_id`, `challenge_id`, `reward_variant` and add them to both forms (see `supabase/functions/fapi-webhook/README.md`).
3. Deploy `start-fapi-checkout` and `fapi-webhook`.
4. Point the FAPI paid notification at `/functions/v1/fapi-webhook?token=<FAPI_WEBHOOK_SECURITY>`.

Prices under the CTAs still come from `diploma_price_cents` / `medal_price_cents` (`price_cents` is the catalog-card fallback).

### Stripe (unused by CTAs)

Stripe Price id columns and the two Stripe edge functions remain for a later cleanup. Pay CTAs no longer open Checkout.

## DEMO — Material scaffold (do not merge)

This branch ships a **debug/profile-only** Flutter Material 3 reference shell so the official `flutter create` / Material template can be inspected next to Viateria. **Do not merge to `main`** unless explicitly asked.

**How to open**

1. Run a debug or profile build (`flutter run` — not `--release`).
2. Sign in as usual. The app still boots to Catalog / the tab shell.
3. Open **Profile** and tap **DEMO — Material scaffold**.
4. Or navigate to `/demo/material`.

Release builds hide the Profile entry and redirect the route to `/`. The demo wraps itself in `ColorScheme.fromSeed`; it does **not** replace `AppTheme` / `BrandColors`.

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
supabase/functions   FAPI checkout + webhook (Stripe leftovers kept)
```
