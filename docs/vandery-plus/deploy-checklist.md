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
