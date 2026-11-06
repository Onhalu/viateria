# VANDERY+ deploy checklist

Do not deploy the membership webhook until these are set on the Edge function. A missing value fails closed. Do not apply this checklist to production until the migration set is explicitly approved.

## Required env

- `FAPI_FORM_URL_VANDERY_PLUS` — recurring checkout form. Empty fails checkout with 500.
- `FAPI_VANDERY_PLUS_AMOUNT_CENTS` — gross price in cents.
- `FAPI_VANDERY_PLUS_ITEM_ID` — FAPI item id.
- `FAPI_VANDERY_PLUS_FORM_ID` — FAPI form id.
- `FAPI_VANDERY_PLUS_PRODUCT_ID` — product code on the invoice item. Required for refunds.

## Item id without product id

If `FAPI_VANDERY_PLUS_ITEM_ID` is set and `FAPI_VANDERY_PLUS_PRODUCT_ID` is empty, every refund is `SKIPPED`. The webhook logs one JSON line and must not be left in that state:

```json
{ "alert": "vandery_plus_config", "message": "FAPI_VANDERY_PLUS_ITEM_ID is set without FAPI_VANDERY_PLUS_PRODUCT_ID; every refund is SKIPPED" }
```

Set both ids together before enabling the FAPI membership webhook.

## FAPI form

- FAPI form: slevové kódy vypnuté (Q6).
- `FAPI_VANDERY_PLUS_RETURN_URL` is the form's thank-you page setting, not a prefill parameter. Set it to `com.viateria.viateria://vandery-plus?vandery_plus=return`. `vanderyPlusPrefillUrl` does not add a return URL.

## Account deletion (prod blocker, Ask first)

Deleting an account anonymizes the membership row and ends access immediately. The FAPI subscription must be stopped at the same time, or FAPI keeps charging. That stop is not implemented. Do not turn on production payments until Ondřej signs it off.

## Drift migrations (local and preview only)

`20261006185900_w0c_drift_challenge_covers_bucket.sql` and `20261006190000_w0b_drift_challenge_windows_changelog.sql` recreate prod history that was never committed. They are for a local or preview database whose chain starts from this repo.

Do not apply them to production. Prod already has these objects. `supabase migration repair` on prod is Ask first.
