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

## Out of scope

GPS verify, offline cache, Story Unlock Modal media, Open-Meteo, SOS, GPX export, leaderboards, regional stats map.

## Stack

Flutter, MapLibre (POI map MVP) + Leaflet/`flutter_map` (challenge maps), Supabase (Auth, Postgres, Storage), Stripe, custom i18n.

## Setup

```bash
flutter pub get
cp .env.example .env   # fill SUPABASE_URL, SUPABASE_ANON_KEY, STRIPE_PUBLISHABLE_KEY, MAP_STYLE_URL
flutter run --dart-define-from-file=.env
```

Without Supabase env vars the app shows a configuration screen instead of inventing catalog content.

## Map Screen MVP

Signed-in home is the **Mapa** tab: full-bleed OSM via MapLibre, custom circular POI icons, clustering, search, filters, map/list toggle, place sheet, and locate.

### `MAP_STYLE_URL`

Pass a MapLibre **style JSON** URL at compile time (not a raster `{z}/{x}/{y}` template):

```bash
flutter run --dart-define=MAP_STYLE_URL=https://api.maptiler.com/maps/streets-v2/style.json?key=YOUR_KEY
# or together with other secrets:
flutter run --dart-define-from-file=.env
```

| Value | What happens |
| --- | --- |
| Set to MapTiler / Stadia / self-hosted OpenMapTiles style | Production basemap |
| Empty / omitted | Non-prod fallback: [OpenFreeMap Liberty](https://tiles.openfreemap.org/styles/liberty) |

**TODO before release:** set `MAP_STYLE_URL` to a production vector-tile provider. Do **not** use `https://tile.openstreetmap.org` as a raster CDN (OSM tile usage policy).

Code: `lib/core/map/map_style_config.dart` (`String.fromEnvironment('MAP_STYLE_URL')`).

### Icons and mock catalog

- Icons: `assets/map/icons/{castle,chateau,ruin,church,other,cluster}@2x.png` — white circle, colored stroke, pictogram; registered with MapLibre `addImage`.
- Catalog: `assets/map/pois.geojson` — 105 Czech monuments as a GeoJSON FeatureCollection (`castle` / `chateau` / `ruin` / `church` / `other`). MVP mock; swap the repository later for a live API.
- Clustering: radius 45, `clusterMaxZoom` 13; tap a cluster to expand.
- Search is **only** over this catalog (no Nominatim autocomplete). Location from the locate FAB stays on-device and is never sent to a backend.

### Module layout

```
lib/features/map/presentation/   MapScreen + overlays
lib/features/map/application/    Riverpod providers
lib/features/map/domain/         POI, filters, search, viewport count
lib/features/map/data/           GeoJSON repo, camera store, location
lib/core/map/                    style URL, camera, runtime flags
lib/core/theme/                  terracotta / glass tokens
lib/core/l10n/                   Czech map copy
```

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
lib/features/map/    MapLibre POI map MVP (this shell's Mapa tab)
lib/domain/          unlock rules, route planner, photo policy
lib/data/            Supabase repositories
lib/l10n/            custom cs/en/de strings
lib/ui/              catalog, challenge, verify, diploma, settings
lib/core/            map style, map theme, map copy
supabase/migrations  Postgres + RLS + Storage
supabase/functions   Stripe checkout + webhook
```
