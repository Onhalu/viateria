# diploma

`POST /functions/v1/diploma` with the user JWT and `{ "challenge_id": "<uuid>" }`.

1. Load the caller's issued `challenge_diplomas` row (`404` if missing, `403` if revoked).
2. Entitlement matches `private.diploma_entitled`: completed participation and (paid purchase, active `diploma_price_cents = 0`, or a free challenge with no active price). The check uses public tables because PostgREST does not expose `private`. `record_diploma_render` runs the SQL function again before the path is stored.
3. `402 { "error": "not_entitled" }` returns before render and upload.
4. Missing `recipient_name_display` → `409 need_name`. No email fallback.
5. `render_hash` hit → signed URL (1 hour). Miss → 1080×1080 PNG with transparent rounded corners (translucent white panel with the black VANDERY lockup and all text), upload to `diplomas/{user_id}/{challenge_id}/{hash}.png`, then the signed URL.

Copy is Czech: `DIPLOM`, `pro`, accusative first name, `za zdolání výzvy`, title, `dne dd.mm.yyyy` (Europe/Prague). Empty template headline/body use those defaults. There is no 9:16 variant and no name editor.

```
deno test --allow-read --allow-net --allow-env supabase/functions/diploma/diploma_test.ts
deno check supabase/functions/diploma/index.ts
```
