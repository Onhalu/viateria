# Viateria

Gamified tourist challenges (SPEC v1). Hikers and cyclists pick a published challenge, follow OSM-mapped waypoints, verify each stop with a **live camera photo**, and earn a 9:16 diploma.

Catalog content is **not** hardcoded in the app. Challenges, waypoints, and promo stripes are authored in **Supabase** (`draft` | `published` | `archived`). The client only renders `published` rows.

## SPEC v1 (in scope)

- Challenge catalog: **open** (all waypoints after access) and **story** (next waypoint unlocks only after the previous is complete)
- Free / paid catalog; **FAPI sales forms** unlock paid challenges (Stripe edge functions remain unused by the CTA)
- **VerifyWaypoint**: GPS within 120 m, otherwise a **live camera photo**
- **RoutePlanner**: hike / bike, km, elevation, time, difficulty, OpenStreetMap link
- Promo widget on the catalog welcome, between Featured and Regions. DB-driven stripes with audience targeting. Exclusive `is_promo` challenges stay out of the ordinary catalog.
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

## Web release (WEDOS / Limitlessdreams)

Production URL: <http://viateria.limitlessdreams.cz/> (domain root, `base-href` `/`). Hosting is WEDOS; Limitlessdreams handles FTP. Android/iOS builds are unchanged.

The compile-time names are the same as local `.env` / `String.fromEnvironment` in `lib/config/app_config.dart` and `lib/map/map_style_config.dart`:

| `--dart-define` / secret | Required for a working site | Source |
| --- | --- | --- |
| `SUPABASE_URL` | **Yes** | `AppConfig.fromEnvironment` |
| `SUPABASE_ANON_KEY` | **Yes** | `AppConfig.fromEnvironment` |
| `MAP_STYLE_URL` | No (falls back to OpenFreeMap Liberty) | `MapStyleConfig.styleUrlFromEnv` |
| `STRIPE_PUBLISHABLE_KEY` | No (unused by pay CTAs) | `AppConfig.fromEnvironment` |
| `USE_ASSET_PLACE_CATALOG` | No (default reads `public.places`) | `AppConfig.fromEnvironment` |

### 1. GitHub Actions secrets

Repo → **Settings → Secrets and variables → Actions → New repository secret**. Names must match the table above (do not invent aliases).

| Secret | Meaning |
| --- | --- |
| `FTP_HOST` | WEDOS FTP hostname |
| `FTP_USER` | FTP username |
| `FTP_PASS` | FTP password |
| `FTP_PATH` | Remote directory relative to the FTP home. Leave unset/empty to use `domains/viateria.limitlessdreams.cz`. Never `/` (main hub) and never `subdom/…` (HTTP 500). |

Pushes to `main` and **Actions → Web release → Run workflow** build `flutter build web --release --base-href=/` and upload the `viateria-web` artifact. If `FTP_HOST` / `FTP_USER` / `FTP_PASS` are set, the same job then FTPS-uploads `build/web` into that remote directory. Deploy never runs on pull requests.

WEDOS FTPS needs `curl --ssl-reqd --ftp-pasv --ftp-skip-pasv-ip --ftp-create-dirs` with per-file retries (`tool/wedos_ftp_upload.sh`). A one-shot `lftp mirror` fails with `425 Security: Bad IP connecting`.

### 2. Local web build

```bash
flutter build web --release --base-href=/ --dart-define-from-file=.env
cp web/.htaccess build/web/.htaccess
```

`<base href="$FLUTTER_BASE_HREF">` in `web/index.html` is rewritten to `/` by `--base-href=/`.

### 3. Apache `.htaccess` (WEDOS)

Apache must serve `index.html` for unknown paths (Flutter web SPA) **and** override WEDOS's default `Cache-Control: max-age=259200` (3 days). Without the cache rules, browsers keep a stale `main.dart.js` after FTP deploy.

`web/.htaccess` is copied into `build/web` by CI. If an FTP client skips dotfiles, upload that file to the domain root. Header rules (`Header always unset Cache-Control` / `Expires`, then `Header always set Cache-Control`) so WEDOS cannot append a second `max-age=259200`:

| Files | `Cache-Control` | Why |
| --- | --- | --- |
| `index.html`, `flutter_bootstrap.js`, `flutter_service_worker.js`, `.last_build_id` | `no-cache, must-revalidate` | Entrypoint / loader / SW / build id must be revalidated on every visit so a new release is picked up. |
| `main.dart.js`, `flutter.js` (and deferred `main.dart.js_N.part.js`) | `max-age=0, must-revalidate` | These filenames are **not** content-hashed; a multi-day cache serves yesterday’s bundle. |
| canvaskit, icons, fonts, wasm, images | `public, max-age=31536000, immutable` | Static / hashed assets; long cache is fine. |

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

Code: `lib/map/map_style_config.dart`. Map places load from Supabase `public.places` (`SupabasePlaceCatalog`). `assets/map/pois.geojson` stays in the repo for tests and for an explicit `USE_ASSET_PLACE_CATALOG=true` dart-define; it is not the production default.

### Supabase

Apply `supabase/migrations/0001_init.sql` (CLI: `supabase db push` or the SQL editor).

Tables: `profiles`, `challenges`, `challenge_i18n`, `waypoints`, `waypoint_i18n`, `challenge_progress`, `waypoint_progress`, `promo_stripes`, `promo_stripe_i18n`, `promo_segments`, `promo_segment_members`, `promo_assignments`, `purchases`, `places`.

### Promo widget (SPEC-promo-widget)

`supabase/migrations/0015_promo_widget.sql` adds `challenges.is_promo`, stripe `kind` (`exclusive` | `discount`) and optional `promo_diploma_price_cents` / `promo_medal_price_cents`, audience tables, and `list_my_promos()`. The app calls that RPC with the signed-in session. It does not ship `service_role`.

Apply the migration yourself (SQL editor or `supabase db push`). This change does not run it.

The catalog list is hero, then Featured (Vybrané), then the promo slot, then Regions. Zero active stripes (or a failed promo fetch) collapse the slot. One stripe is a forest card. Two or more snap in a carousel. Tap opens the linked challenge. `shellFill` stays on the welcome header and the bottom nav only.

Ordinary catalog queries exclude `is_promo = true`. An exclusive challenge is readable when the caller matches a published, in-window stripe for that challenge. A discount stripe leaves the challenge listed. `start-fapi-checkout` uses `promo_*_price_cents` from an active discount stripe when those values are set.

**Test A** is in the migration: challenge slug `promo-mock` (`is_promo`), one published exclusive stripe `c0ffee00-0000-4000-8000-000000000002` ending 14 days after apply, and **no** `promo_assignments` row, so every signed-in user sees it. Empty segments `new_users` and `cz_users` are seeded too.

**Test B** — show that stripe only to Ondřej. Look up the profile, then insert one assignment. Any assignment row replaces “everyone”:

```sql
select id, display_name, email
from public.profiles
where display_name ilike '%ondřej%'
   or display_name ilike '%ondrej%'
   or email ilike '%ondrej%';

insert into public.promo_assignments (promo_stripe_id, target_type, user_id)
values (
  'c0ffee00-0000-4000-8000-000000000002',
  'user',
  '<ondrej-profile-uuid>'
);
```

Delete that row to restore Test A.

Author content in the dashboard. Only `status = published` is visible. Publish translations for `cs`, `en`, and `de`.

Edge functions:

- `start-fapi-checkout` — authenticated; calls `challenge_readable` (same promo gate as the catalog) before upserting a pending purchase and returning the FAPI form URL
- `fapi-webhook` — requires `FAPI_WEBHOOK_SECURITY`; marks an existing pending `purchases` row `paid` on a verified FAPI paid-invoice notification
- `send-email` — Auth Send Email hook; requires `SEND_EMAIL_HOOK_SECRET` and a valid webhook signature before it sends
- `create-checkout-session` / `stripe-webhook` — leftover Stripe path; not used by the Flutter pay CTAs

Set function secrets: `FAPI_API_USERNAME`, `FAPI_API_KEY`, required `FAPI_WEBHOOK_SECURITY`, required `SEND_EMAIL_HOOK_SECRET`, and optional `FAPI_CUSTOM_FIELD_ID_*`. Details: `supabase/functions/fapi-webhook/README.md`. Legacy Stripe secrets stay documented for the unused functions: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`.

`supabase/migrations/0018_verify_waypoint_challenge_readable.sql` makes `verify_waypoint` use `private.challenge_readable` and adds the public wrapper checkout calls. It is 0018 so it sorts after the story migrations `0016` / `0017`. Apply it yourself before deploying `start-fapi-checkout`. This change does not run it.

Storage bucket: `waypoint-photos` (`{user_id}/{challenge_id}/{waypoint_id}/{uuid}.jpg`).

### Auth

One Supabase client (`Supabase.initialize` in `lib/main.dart`). `auth.uid()` is the user for `profiles`, `purchases`, `challenge_progress`, `waypoint_progress`, and photo uploads. The app does not call anonymous sign-in, and it never ships the `service_role` key.

There is no legacy anonymous user to merge. Visited map places and the last-opened challenge were device-local (`SharedPreferences`). The first signed-in account adopts that snapshot; each later account on the same device keeps its own copy, keyed by `auth.uid()`.

**Signed out.** The router sends every shell route to `/auth`. That gate was already there: published challenges, waypoints, and promos are `authenticated`-only in RLS, so the catalog cannot load without a session. `public.places` is readable by `anon`, but the map UI lives inside the signed-in shell, so it is not browsed while signed out. Verify, purchases, and profile stay on `auth.uid()`.

**Signed in.** Email + password, email magic link (or the 6-digit code), Google, and Apple all create the same kind of session. Logout is on the profile screen. If Google or Apple is not enabled in the Supabase dashboard yet, that button shows a clear error and email sign-in still works.

OAuth uses PKCE (`FlutterAuthClientOptions.authFlowType`, the supabase_flutter 2.17 default). The SDK's deep-link observer exchanges the `code`; the app does not call `getSessionFromUrl` itself.

| Platform | `redirectTo` the app sends |
| --- | --- |
| iOS and Android | `com.viateria.viateria://login-callback` |
| Web | Current origin, query and fragment stripped. Production: `https://viateria.limitlessdreams.cz/` |

Google Cloud and Apple Developer do **not** get the app deep link. They get Supabase's provider callback: `https://yzmbxxgesnbsqygzgdky.supabase.co/auth/v1/callback`.

**Forgot password.** Sign-in emails a reset link with `resetPasswordForEmail`. `redirectTo` is the same value as OAuth and magic link (the table above). Those URLs already belong in Supabase Auth → Additional Redirect URLs; recovery does not add another one. Opening the link starts a recovery session and the app stays on the new-password screen until `updateUser` saves the password.

Dashboard checklist (providers, redirect URLs, Google web client, Apple Services ID) is in the pull request for this change. Apply `supabase/migrations/0010_oauth_profile_name.sql` so a Google or Apple name is copied onto `profiles.display_name` at signup. That column is display-only; RLS is unchanged.

### FAPI

1. Create two sales forms in FAPI (digital diploma, medal + diploma). Do not invent URLs in the repo — paste each public form-page URL into `challenges.fapi_form_url_diploma` / `fapi_form_url_medal` when ready. A null/empty URL disables that pay CTA.
2. Create custom fields named `user_id`, `challenge_id`, `reward_variant` and add them to both forms (see `supabase/functions/fapi-webhook/README.md`).
3. Deploy `start-fapi-checkout` and `fapi-webhook`.
4. Point the FAPI paid notification at `/functions/v1/fapi-webhook?token=<FAPI_WEBHOOK_SECURITY>`. The secret is required; an empty value rejects the notification.

Prices under the CTAs still come from `diploma_price_cents` / `medal_price_cents` (`price_cents` is the catalog-card fallback). An active **discount** promo stripe for that challenge overrides the charged amount with `promo_diploma_price_cents` / `promo_medal_price_cents` when the column is set. Exclusive stripes do not change the price.

### Stripe (unused by CTAs)

Stripe Price id columns and the two Stripe edge functions remain for a later cleanup. Pay CTAs no longer open Checkout.

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

Paid challenges require `purchases.status = paid`. The `verify_waypoint` RPC enforces photo path, access, story order, and the same promo readability rule as the catalog (`private.challenge_readable`). It does not check GPS or that a storage object exists.

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
