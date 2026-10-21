# diploma

`POST /functions/v1/diploma` with the user JWT and `{ "challenge_id": "<uuid>" }`.

1. Load the caller's issued `challenge_diplomas` row (`404` if missing, `403` if revoked).
2. Entitlement matches `private.diploma_entitled`: completed participation and (paid purchase, active `diploma_price_cents = 0`, or a free challenge with no active price). The check uses public tables because PostgREST does not expose `private`. `record_diploma_render` runs the SQL function again before the path is stored.
3. `402 { "error": "not_entitled" }` returns before render and upload.
4. Missing `recipient_name_display` → `409 need_name`. No email fallback.
5. `render_hash` hit → signed URL (1 hour). Miss → 1080×1080 PNG with transparent rounded corners (layout B "Editoriál": 62 % white panel, small black VANDERY lockup, spaced DIPLOM label, upright `pro` / `za zdolání výzvy` — Bricolage Grotesque has no italic — hairlines, date anchored at the bottom; the challenge name is uppercase Bricolage Grotesque 700 at +4% tracking; variants v4/A–D stay selectable via `DIPLOMA_LAYOUT`). Line widths are measured from the TTF with opentype.js (estimate 0.52 em as fallback); names shrink and wrap, upload to `diplomas/{user_id}/{challenge_id}/{hash}.png`, then the signed URL. A font change needs a redeploy of this function; cached PNGs stay until `RENDERER_VERSION` misses.

Copy is Czech: `DIPLOM`, `pro`, accusative first name, `za zdolání výzvy`, title, `dne dd.mm.yyyy` (Europe/Prague). Empty template headline/body use those defaults. There is no 9:16 variant and no name editor.

```
deno test --allow-read --allow-net --allow-env supabase/functions/diploma/diploma_test.ts
deno check supabase/functions/diploma/index.ts
```
